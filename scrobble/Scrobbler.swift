//
//  Scrobbler.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import Combine
import MediaPlayer
import MusicKit
import ScriptingBridge
import CommonCrypto
import Network
import Network
import AppKit
import Observation


@objc enum MusicEPlS: Int {
    case stopped = 1800426323 // 'kPSS'
    case playing = 1800426320 // 'kPSP'
    case paused = 1800426352  // 'kPSp'
}

@objc protocol MusicApplication {
    @objc optional var currentTrack: MusicTrack { get }
    @objc optional var playerState: MusicEPlS { get }
}

@objc protocol MusicTrack {
    @objc optional var name: String { get }
    @objc optional var artist: String { get }
    @objc optional var album: String { get }
}



@Observable
class Scrobbler {
    let lastFmManager: LastFmManagerType
    private var scrobblingServices: [ScrobblingService] = []
    @MainActor var servicesLastUpdated = Date() // This will trigger UI updates when services change

    var currentTrack: String = "No track playing"
    var currentArtwork: NSImage? = nil
    var isScrobbling: Bool = false
    var lastScrobbledTrack: String = ""
    var errorMessage: String?
    var musicAppStatus: String = "Connecting to Music app..."
    
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.lastfm.scrobbler", qos: .background)
    private var lastScrobbleTime: Date?
    private let minimumScrobbleInterval: TimeInterval = 30
    private var pollTimer: Timer?
    
    private var currentTrackStartTime: Date?
    private var currentTrackDuration: TimeInterval?
    private var scrobbleTimer: Timer?
    private var hasScrobbledCurrentSession = false
    
    private var _mediaRemoteFetcher: NowPlayingFetcher?
    
    // Expose the fetcher for UI components that need to check running apps
    var mediaRemoteFetcher: NowPlayingFetcher? {
        return _mediaRemoteFetcher
    }
    
    // Add reference to preferences manager to monitor app changes
    private var preferencesManager: PreferencesManager?
    
    init(lastFmManager: LastFmManagerType, preferencesManager: PreferencesManager? = nil) {
        self.lastFmManager = lastFmManager
        
        self.preferencesManager = preferencesManager
        
        // Initialize scrobbling services
        setupScrobblingServices(preferencesManager: preferencesManager)
        
        // Monitor preferences changes for scrobbling service settings
        if let prefManager = preferencesManager {
            startPreferencesObservation(prefManager)
        }
        
        // Initialize with the selected app from preferences
        if let prefManager = preferencesManager {
            self._mediaRemoteFetcher = NowPlayingFetcher(targetApp: prefManager.selectedMusicApp)
        } else {
            // Fallback to default Apple Music
            let defaultApp = SupportedMusicApp.allApps.first(where: { $0.bundleId == "com.apple.music" })!
            self._mediaRemoteFetcher = NowPlayingFetcher(targetApp: defaultApp)
        }
        
        if self._mediaRemoteFetcher != nil {
            self._mediaRemoteFetcher?.setupAndStart()
            Log.debug("MediaRemoteTestFetcher initialized successfully")
        }
        
        setupMusicAppObserver()
        startPolling()
        checkNowPlaying()
        
    }
    
    private func startPreferencesObservation(_ prefManager: PreferencesManager) {
        // Recursive observation loop
        withObservationTracking {
            // Read the properties we care about to register dependency
            _ = prefManager.enableLastFm
            _ = prefManager.enableCustomScrobbler
            _ = prefManager.blueskyHandle
        } onChange: { [weak self] in
            Log.debug("Scrobbler: Preferences changed, scheduling refresh")
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.refreshScrobblingServices()
                // Re-register observation
                self.startPreferencesObservation(prefManager)
            }
        }
    }
    
    private func setupScrobblingServices(preferencesManager: PreferencesManager?) {
        scrobblingServices.removeAll()
        
        guard let prefManager = preferencesManager else { return }
        
        // Add Last.fm service if enabled
        if prefManager.enableLastFm {
            let lastFmService = LastFmServiceAdapter(lastFmManager: lastFmManager)
            scrobblingServices.append(lastFmService)
        }
        
        // Add custom scrobbling service if enabled
        if prefManager.enableCustomScrobbler && !prefManager.blueskyHandle.isEmpty {
            let customService = CustomScrobblingService(blueskyHandle: prefManager.blueskyHandle)
            scrobblingServices.append(customService)
        }
        
        // Subscribe to authentication state changes for all services
        for service in scrobblingServices {
            Task { @MainActor in
                for await _ in service.authStatus {
                    Log.debug("Service auth state changed: \(service.serviceName)", category: .auth)
                    self.servicesLastUpdated = Date()
                }
            }
        }
        
        // Trigger UI update
        Task { @MainActor in
            self.servicesLastUpdated = Date()
        }
        
        Log.debug("Initialized \(scrobblingServices.count) scrobbling services")
    }
    
    // Method to refresh services when preferences change
    func refreshScrobblingServices() {
        setupScrobblingServices(preferencesManager: preferencesManager)
    }
    
    // Get all available services for UI
    func getScrobblingServices() -> [ScrobblingService] {
        return scrobblingServices
    }
    
    // Method to change the target music app
    func setTargetMusicApp(_ app: SupportedMusicApp) {
        Log.debug("Scrobbler switching to target app: \(app.displayName)", category: .scrobble)
        
        // Clear current track display immediately
        Task { @MainActor in
            self.currentTrack = "Switching to \(app.displayName)..."
            self.currentArtwork = nil
        }
        
        // Switch the fetcher
        _mediaRemoteFetcher?.setTargetApp(app)
        
        // Update the status to reflect the change
        musicAppStatus = "Connected to \(app.displayName)"
        
        // Schedule multiple checks to ensure we catch the new app's state
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            Log.debug("First check after app switch", category: .scrobble)
            self.checkNowPlaying()
            
            try? await Task.sleep(for: .seconds(0.5))
            Log.debug("🔍 Second check after app switch", category: .scrobble)
            self.checkNowPlaying()
            
            try? await Task.sleep(for: .seconds(1.0))
            Log.debug("🔍 Final check after app switch", category: .scrobble)
            self.checkNowPlaying()
        }
    }
    
    // Debug method to get current target app
    func getCurrentTargetApp() -> SupportedMusicApp? {
        return _mediaRemoteFetcher?.currentTargetApp
    }
    
    private func setupMusicAppObserver() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleMusicPlayerNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
        
        musicAppStatus = "Connected to Music app"
    }
    
    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.checkNowPlaying()
        }
    }
    
    @objc private func handleMusicPlayerNotification(_ notification: Notification) {
        checkNowPlaying()
    }
    
    private func checkNowPlaying() {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            Log.debug("Checking now playing...", category: .scrobble)
            
            if let trackInfo = self.getCurrentTrackInfoViaFetcher(){
                let trackString = "\(trackInfo.artist) - \(trackInfo.name)"
                
                Log.debug("Found track: \(trackString) from app: \(trackInfo.application)", category: .scrobble)
                
                Task { @MainActor in
                    // If we're getting the same track info, this is likely just a polling update
                    let isSameTrack = trackString == self.currentTrack
                    self.currentTrack = trackString
                    
                    self.currentArtwork = trackInfo.artwork
                    
                    // Only update now playing status and setup scrobble timer if this is a new track
                    if !isSameTrack {
                        Log.debug("New track detected, updating now playing and setting up scrobble timer", category: .scrobble)
                        // Reset scrobble session flag for new track
                        self.hasScrobbledCurrentSession = false
                        
                        // Update Now Playing (Async)
                        Task {
                            await self.updateNowPlaying(artist: trackInfo.artist, title: trackInfo.name, album: trackInfo.album)
                        }
                        
                        self.setupScrobbleTimer(artist: trackInfo.artist, title: trackInfo.name, album: trackInfo.album)
                    } else {
                        Log.debug("Same track continuing, skipping now playing update", category: .scrobble)
                    }
                }
            } else {
                Log.debug("No track info found", category: .scrobble)
                Task { @MainActor in
                    if self.currentTrack != "No track playing" {
                        Log.debug("No track playing detected, updating UI and invalidating timers", category: .scrobble)
                        self.currentTrack = "No track playing"
                        self.currentArtwork = nil
                        self.invalidateScrobbleTimer()
                    }
                }
            }
        }
    }
    

    private func getCurrentTrackInfoViaFetcher() -> (name: String, artist: String, album: String, duration: TimeInterval?, application: String, artwork: NSImage?)? {
        Log.debug("Fetching current track info via MediaRemoteTestFetcher", category: .scrobble)
        guard let fetcher = _mediaRemoteFetcher else {
            Log.debug("MediaRemoteTestFetcher not initialized", category: .scrobble)
            return nil
        }
        
        Log.debug("Current target app: \(fetcher.currentTargetApp?.displayName ?? "none")", category: .scrobble)
        
        let trackInfo = fetcher.fetchCurrentTrackInfo()
        
        Log.debug("Track info from fetcher: isPlaying=\(trackInfo.isPlaying), title='\(trackInfo.title)', artist='\(trackInfo.artist)', app='\(trackInfo.application)'", category: .scrobble)
        
        guard trackInfo.isPlaying else {
            Log.debug("No track currently playing (isPlaying = false) in MediaRemoteTestFetcher", category: .scrobble)
            return nil
        }
        guard !trackInfo.title.isEmpty, !trackInfo.artist.isEmpty else {
            Log.debug("No track currently playing (empty title/artist) in MediaRemoteTestFetcher", category: .scrobble)
            return nil
        }
        Log.debug("Returning valid track info: \(trackInfo.artist) - \(trackInfo.title)", category: .scrobble)
        return (name: trackInfo.title, artist: trackInfo.artist, album: trackInfo.album, duration: trackInfo.duration, application: trackInfo.application, artwork: trackInfo.artwork)
    }
    
    private func scrobbleTrack(artist: String, title: String, album: String) {
        // Prevent duplicate scrobbles for the current play session
        if hasScrobbledCurrentSession {
            Log.debug("Preventing duplicate scrobble for current play session: \(artist) - \(title)", category: .scrobble)
            return
        }
        
        Log.debug("Attempting to scrobble: \(artist) - \(title)", category: .scrobble)
        isScrobbling = true
        errorMessage = nil
        
        // Mark this session as scrobbled
        hasScrobbledCurrentSession = true
        
        Task {
            // Scrobble to all enabled services in parallel
            await withTaskGroup(of: (String, Bool).self) { group in
                for service in self.scrobblingServices {
                    group.addTask {
                        do {
                            let result = try await service.scrobble(artist: artist, track: title, album: album)
                            return (service.serviceName, result)
                        } catch {
                            Log.error("Scrobble error for \(service.serviceName): \(error)", category: .scrobble)
                            return (service.serviceName, false)
                        }
                    }
                }
                
                var successes: [String] = []
                var failures: [String] = []

                for await (name, success) in group {
                    if success {
                        successes.append(name)
                    } else {
                        failures.append(name)
                    }
                }

                // Capture results before passing to MainActor
                let successList = successes
                let failureList = failures

                await MainActor.run {
                    self.isScrobbling = false

                    if !successList.isEmpty {
                        self.lastScrobbledTrack = "\(artist) - \(title)"
                        Log.debug("Successfully scrobbled to: \(successList.joined(separator: ", "))", category: .scrobble)
                    }

                    if !failureList.isEmpty {
                        let failureNames = failureList.joined(separator: ", ")
                        self.errorMessage = "Failed to scrobble to: \(failureNames)"
                        Log.error("Failed to scrobble to: \(failureNames)", category: .scrobble)
                    }
                }
            }
        }
    }
    
    private func setupScrobbleTimer(artist: String, title: String, album: String) {
        invalidateScrobbleTimer()
        
        // Get the track duration
        if let trackInfo = getCurrentTrackInfoViaFetcher() {
            let duration = trackInfo.duration ?? 0
            Log.debug("Setting up scrobble timer for track with duration: \(duration) seconds", category: .scrobble)
            
            // Only setup timer if track is longer than 30 seconds
            guard duration > 30 else {
                Log.debug("Track too short to scrobble (\(duration) seconds)", category: .scrobble)
                return
            }
            
            currentTrackStartTime = Date()
            currentTrackDuration = duration
            
            // Calculate when to scrobble - either half duration or 4 minutes
            let scrobbleDelay = min(duration / 2, 240)
            Log.debug("Will scrobble after \(scrobbleDelay) seconds", category: .scrobble)
            
            // Create a timer that runs on the main run loop to ensure it stays active
            DispatchQueue.main.async {
                self.scrobbleTimer = Timer(timeInterval: scrobbleDelay, repeats: false) { [weak self] _ in
                    Log.debug("Scrobble timer fired", category: .scrobble)
                    self?.scrobbleTrack(artist: artist, title: title, album: album)
                }
                // Make sure the timer runs even when scrolling
                RunLoop.main.add(self.scrobbleTimer!, forMode: .common)
            }
        } else {
            Log.error("Could not get track duration", category: .scrobble)
        }
    }
    
    private func invalidateScrobbleTimer() {
        scrobbleTimer?.invalidate()
        scrobbleTimer = nil
        currentTrackStartTime = nil
        currentTrackDuration = nil
        // Reset session flag when track stops/changes
        hasScrobbledCurrentSession = false
    }
    
    private func updateNowPlaying(artist: String, title: String, album: String) async {
        // Update now playing for all enabled services
        await withTaskGroup(of: (String, Bool).self) { group in
            for service in self.scrobblingServices {
                group.addTask {
                    do {
                        let result = try await service.updateNowPlaying(artist: artist, track: title, album: album)
                        return (service.serviceName, result)
                    } catch {
                        Log.error("Now playing error for \(service.serviceName): \(error)", category: .scrobble)
                        return (service.serviceName, false)
                    }
                }
            }
            
            var successes: [String] = []
            var failures: [String] = []
            
            for await (name, success) in group {
                if success {
                    successes.append(name)
                } else {
                    failures.append(name)
                }
            }
            
            // Optional: Update UI or Log on MainActor
            if !successes.isEmpty {
                Log.debug("Successfully updated now playing for: \(successes.joined(separator: ", "))", category: .scrobble)
            }
            if !failures.isEmpty {
                 Log.error("Failed to update now playing for: \(failures.joined(separator: ", "))", category: .scrobble)
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        pollTimer?.invalidate()
        scrobbleTimer?.invalidate()
    }
}

extension Scrobbler {
    func logDebugInfo(_ message: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        Log.debug("[\(timestamp)] \(message)", category: .scrobble)
    }
}

