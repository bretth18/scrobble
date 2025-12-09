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
import AppKit


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



class Scrobbler: ObservableObject {
    let lastFmManager: LastFmManagerType
    private var scrobblingServices: [ScrobblingService] = []
    @Published var servicesLastUpdated = Date() // This will trigger UI updates when services change

    @Published var currentTrack: String = "No track playing"
    @Published var currentArtwork: NSImage? = nil
    @Published var isScrobbling: Bool = false
    @Published var lastScrobbledTrack: String = ""
    @Published var errorMessage: String?
    @Published var musicAppStatus: String = "Connecting to Music app..."
    
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
            print("MediaRemoteTestFetcher initialized successfully")
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
            print("Scrobbler: Preferences changed, scheduling refresh")
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
            
            // Subscribe to authentication state changes to trigger UI updates
            customService.authenticationPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] isAuthenticated in
                    print("🔄 Custom service authentication state changed to: \(isAuthenticated)")
                    self?.servicesLastUpdated = Date()
                }
                .store(in: &cancellables)
            
            scrobblingServices.append(customService)
        }
        
        // Trigger UI update
        DispatchQueue.main.async {
            self.servicesLastUpdated = Date()
        }
        
        print("Initialized \(scrobblingServices.count) scrobbling services")
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
        print("🎵 Scrobbler switching to target app: \(app.displayName)")
        
        // Clear current track display immediately
        DispatchQueue.main.async {
            self.currentTrack = "Switching to \(app.displayName)..."
            self.currentArtwork = nil
        }
        
        // Switch the fetcher
        _mediaRemoteFetcher?.setTargetApp(app)
        
        // Update the status to reflect the change
        musicAppStatus = "Connected to \(app.displayName)"
        
        // Schedule multiple checks to ensure we catch the new app's state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔍 First check after app switch")
            self.checkNowPlaying()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🔍 Second check after app switch")
            self.checkNowPlaying()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            print("🔍 Final check after app switch")
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
            
            print("🔍 Checking now playing...")
            
            if let trackInfo = self.getCurrentTrackInfoViaFetcher(){
                let trackString = "\(trackInfo.artist) - \(trackInfo.name)"
                print("✅ Found track: \(trackString) from app: \(trackInfo.application)")
                
                DispatchQueue.main.async {
                    // If we're getting the same track info, this is likely just a polling update
                    let isSameTrack = trackString == self.currentTrack
                    self.currentTrack = trackString
                    
                    self.currentArtwork = trackInfo.artwork
                    
                    // Only update now playing status and setup scrobble timer if this is a new track
                    if !isSameTrack {
                        print("🆕 New track detected, updating now playing and setting up scrobble timer")
                        // Reset scrobble session flag for new track
                        self.hasScrobbledCurrentSession = false
                        self.updateNowPlaying(artist: trackInfo.artist, title: trackInfo.name, album: trackInfo.album)
                        self.setupScrobbleTimer(artist: trackInfo.artist, title: trackInfo.name, album: trackInfo.album)
                    } else {
                        print("🔄 Same track continuing, skipping now playing update")
                    }
                }
            } else {
                print("❌ No track info found")
                DispatchQueue.main.async {
                    if self.currentTrack != "No track playing" {
                        print("🔇 No track playing, invalidating timers")
                        self.currentTrack = "No track playing"
                        self.currentArtwork = nil
                        self.invalidateScrobbleTimer()
                    }
                }
            }
        }
    }
    
    private func getCurrentTrackInfo() -> (name: String, artist: String, album: String, duration: TimeInterval?)? {
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                set trackDuration to duration of current track
                return trackName & "|" & trackArtist & "|" & trackAlbum & "|" & trackDuration
            else
                return ""
            end if
        end tell
        """

        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        guard let result = appleScript?.executeAndReturnError(&error).stringValue,
              !result.isEmpty else {
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error getting track info: \(error)"
                }
            }
            return nil
        }
        
        let components = result.components(separatedBy: "|")
        guard components.count == 4,
              !components[0].isEmpty,
              !components[1].isEmpty,
              !components[2].isEmpty else {
            return nil
        }
        
        let duration = TimeInterval(components[3]) ?? 0
        
        
        return (name: components[0], artist: components[1], album: components[2], duration: duration)
    }
    
    private func getCurrentTrackInfoNew() -> (name: String, artist: String, album: String, duration: TimeInterval?, application: String)? {
        let script = """
            use framework "Foundation"
            use framework "AppKit"
            use scripting additions

            on getNowPlayingInfoAsString()
                set mediaRemoteBundle to current application's NSBundle's bundleWithPath:"/System/Library/PrivateFrameworks/MediaRemote.framework"
                mediaRemoteBundle's load()
                
                set MRNowPlayingRequest to current application's NSClassFromString("MRNowPlayingRequest")
                if MRNowPlayingRequest is missing value then
                    error "MRNowPlayingRequest class not found."
                end if
                
                set nowItem to MRNowPlayingRequest's localNowPlayingItem()
                if nowItem is missing value then return ""
                
                set infoDict to nowItem's nowPlayingInfo()
                
                -- Fetch metadata
                set title to infoDict's valueForKey:"kMRMediaRemoteNowPlayingInfoTitle"
                if title is missing value then set title to ""
                set artist to infoDict's valueForKey:"kMRMediaRemoteNowPlayingInfoArtist"
                if artist is missing value then set artist to ""
                set album to infoDict's valueForKey:"kMRMediaRemoteNowPlayingInfoAlbum"
                if album is missing value then set album to ""
                set duration to infoDict's valueForKey:"kMRMediaRemoteNowPlayingInfoDuration"
                if duration is missing value then set duration to 0
                set rate to infoDict's valueForKey:"kMRMediaRemoteNowPlayingInfoPlaybackRate"
                if rate is missing value then set rate to 0
                
                -- App name
                set appName to MRNowPlayingRequest's localNowPlayingPlayerPath()'s client()'s displayName()
                if appName is missing value then set appName to ""
                
                -- Playback state
                set isPlaying to "false"
                if (rate as real) > 0 then set isPlaying to "true"
                
                -- Join as pipe-separated string
                set resultString to (title as text) & "|" & (artist as text) & "|" & (album as text) & "|" & (duration as string) & "|" & (appName as text) & "|" & isPlaying
                
                return resultString
            end getNowPlayingInfoAsString
            getNowPlayingInfoAsString()
            """
        
        let appleScript = NSAppleScript(source: script)
        var error: NSDictionary?
        
        guard let result = appleScript?.executeAndReturnError(&error).stringValue,
              !result.isEmpty else {
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error getting track info: \(error)"
                }
            }
            return nil
        }
        
        let components = result.components(separatedBy: "|")
        guard components.count == 6,
                !components[0].isEmpty,
                !components[1].isEmpty,
                !components[2].isEmpty,
                !components[4].isEmpty,
              !components[5].isEmpty else {
            return nil
        }
        
        let name = components[0]
        let artist = components[1]
        let album = components[2]
        let duration = TimeInterval(components[3]) ?? 0
        let application = components[4]
        let isPlaying = components[5] == "true"

        
        
        // Only return info if something is actually playing
        guard isPlaying else {
            return nil
        }
        
        return (name: name, artist: artist, album: album, duration: duration, application: application)
        
    }
    

    
    private func getCurrentTrackInfoViaFetcher() -> (name: String, artist: String, album: String, duration: TimeInterval?, application: String, artwork: NSImage?)? {
        print("📱 Fetching current track info via MediaRemoteTestFetcher")
        guard let fetcher = _mediaRemoteFetcher else {
            print("❌ MediaRemoteTestFetcher not initialized")
            return nil
        }
        
        print("🎯 Current target app: \(fetcher.currentTargetApp?.displayName ?? "none")")
        
        let trackInfo = fetcher.fetchCurrentTrackInfo()
        
        print("📊 Track info from fetcher: isPlaying=\(trackInfo.isPlaying), title='\(trackInfo.title)', artist='\(trackInfo.artist)', app='\(trackInfo.application)'")
        
        guard trackInfo.isPlaying else {
            print("⏸️ No track currently playing (isPlaying = false) in MediaRemoteTestFetcher")
            return nil
        }
        guard !trackInfo.title.isEmpty, !trackInfo.artist.isEmpty else {
            print("📭 No track currently playing (empty title/artist) in MediaRemoteTestFetcher")
            return nil
        }
        print("✅ Returning valid track info: \(trackInfo.artist) - \(trackInfo.title)")
        return (name: trackInfo.title, artist: trackInfo.artist, album: trackInfo.album, duration: trackInfo.duration, application: trackInfo.application, artwork: trackInfo.artwork)
    }
    
    private func scrobbleTrack(artist: String, title: String, album: String) {
        // Prevent duplicate scrobbles for the current play session
        if hasScrobbledCurrentSession {
            print("⚠️ Preventing duplicate scrobble for current play session: \(artist) - \(title)")
            return
        }
        
        print("Attempting to scrobble: \(artist) - \(title)")
        isScrobbling = true
        errorMessage = nil
        
        // Mark this session as scrobbled
        hasScrobbledCurrentSession = true
        
        // Scrobble to all enabled services
        let publishers = scrobblingServices.map { service in
            service.scrobble(artist: artist, track: title, album: album)
                .map { success in (service: service, success: success) }
                .catch { error in
                    print("Scrobble error for \(service.serviceName): \(error)")
                    return Just((service: service, success: false))
                }
        }
        
        if publishers.isEmpty {
            // Fallback to original Last.fm manager if no services configured
            lastFmManager.scrobble(artist: artist, track: title, album: album)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    self?.isScrobbling = false
                    switch completion {
                    case .finished:
                        print("Scrobble request completed")
                    case .failure(let error):
                        self?.errorMessage = "Scrobble error: \(error.localizedDescription)"
                        print("Scrobble error: \(error)")
                    }
                }, receiveValue: { [weak self] success in
                    if success {
                        self?.lastScrobbledTrack = "\(artist) - \(title)"
                        print("Successfully scrobbled: \(artist) - \(title)")
                    } else {
                        self?.errorMessage = "Failed to scrobble: \(artist) - \(title)"
                        print("Failed to scrobble: \(artist) - \(title)")
                    }
                })
                .store(in: &cancellables)
        } else {
            // Use new multi-service approach
            Publishers.MergeMany(publishers)
                .collect()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] results in
                    self?.isScrobbling = false
                    
                    let successfulScrobbles = results.filter { $0.success }
                    let failedScrobbles = results.filter { !$0.success }
                    
                    if !successfulScrobbles.isEmpty {
                        self?.lastScrobbledTrack = "\(artist) - \(title)"
                        let successNames = successfulScrobbles.map { $0.service.serviceName }.joined(separator: ", ")
                        print("Successfully scrobbled to: \(successNames)")
                    }
                    
                    if !failedScrobbles.isEmpty {
                        let failureNames = failedScrobbles.map { $0.service.serviceName }.joined(separator: ", ")
                        self?.errorMessage = "Failed to scrobble to: \(failureNames)"
                        print("Failed to scrobble to: \(failureNames)")
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    private func setupScrobbleTimer(artist: String, title: String, album: String) {
        invalidateScrobbleTimer()
        
        // Get the track duration
        if let trackInfo = getCurrentTrackInfoViaFetcher() {
            let duration = trackInfo.duration ?? 0
            print("Setting up scrobble timer for track with duration: \(duration) seconds")
            
            // Only setup timer if track is longer than 30 seconds
            guard duration > 30 else {
                print("Track too short to scrobble (\(duration) seconds)")
                return
            }
            
            currentTrackStartTime = Date()
            currentTrackDuration = duration
            
            // Calculate when to scrobble - either half duration or 4 minutes
            let scrobbleDelay = min(duration / 2, 240)
            print("Will scrobble after \(scrobbleDelay) seconds")
            
            // Create a timer that runs on the main run loop to ensure it stays active
            DispatchQueue.main.async {
                self.scrobbleTimer = Timer(timeInterval: scrobbleDelay, repeats: false) { [weak self] _ in
                    print("Scrobble timer fired")
                    self?.scrobbleTrack(artist: artist, title: title, album: album)
                }
                // Make sure the timer runs even when scrolling
                RunLoop.main.add(self.scrobbleTimer!, forMode: .common)
            }
        } else {
            print("Could not get track duration")
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
    
    private func updateNowPlaying(artist: String, title: String, album: String) {
        // Update now playing for all enabled services
        let publishers = scrobblingServices.map { service in
            service.updateNowPlaying(artist: artist, track: title, album: album)
                .map { success in (service: service, success: success) }
                .catch { error in
                    print("Now playing error for \(service.serviceName): \(error)")
                    return Just((service: service, success: false))
                }
        }
        
        if publishers.isEmpty {
            // Fallback to original Last.fm manager if no services configured
            lastFmManager.updateNowPlaying(artist: artist, track: title, album: album)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to update now playing: \(error)")
                    }
                }, receiveValue: { success in
                    if success {
                        print("Successfully updated now playing status")
                    }
                })
                .store(in: &cancellables)
        } else {
            // Use new multi-service approach
            Publishers.MergeMany(publishers)
                .collect()
                .receive(on: DispatchQueue.main)
                .sink { results in
                    let successfulUpdates = results.filter { $0.success }
                    if !successfulUpdates.isEmpty {
                        let successNames = successfulUpdates.map { $0.service.serviceName }.joined(separator: ", ")
                        print("Successfully updated now playing for: \(successNames)")
                    }
                    
                    let failedUpdates = results.filter { !$0.success }
                    if !failedUpdates.isEmpty {
                        let failureNames = failedUpdates.map { $0.service.serviceName }.joined(separator: ", ")
                        print("Failed to update now playing for: \(failureNames)")
                    }
                }
                .store(in: &cancellables)
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
        print("[\(timestamp)] \(message)")
    }
}

