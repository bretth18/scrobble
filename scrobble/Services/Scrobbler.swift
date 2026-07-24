//
//  Scrobbler.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import MediaPlayer
import MusicKit
import ScriptingBridge
import CommonCrypto
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



// MARK: - Testable Scrobble Delay Calculation

func calculateScrobbleDelay(trackDuration: Double, completionPercentage: Int, useMaxDelay: Bool, maxDelay: Int?) -> Double? {
    guard trackDuration > 30 else { return nil }
    let percentageDelay = trackDuration * Double(completionPercentage) / 100.0
    if useMaxDelay, let maxDelay = maxDelay {
        return min(percentageDelay, Double(maxDelay))
    }
    return percentageDelay
}

@Observable
@MainActor
class Scrobbler {
    let lastFmManager: LastFmManagerType
    private var scrobblingServices: [ScrobblingService] = []
    var servicesLastUpdated = Date() // This will trigger UI updates when services change

    var currentTrack: String = "No track playing"
    var currentArtwork: NSImage? = nil

    /// Cleaned-but-unresolved track identity from the poller. `currentTrack`
    /// is the *display* string and may be rewritten by async web metadata
    /// resolution; this key is what same-track detection compares against.
    private var currentRawTrackKey = ""
    private var resolutionTask: Task<Void, Never>?
    /// Metadata the scrobble timer submits at fire time — updated in place
    /// when web metadata resolution lands mid-play.
    private var pendingScrobbleMetadata: (artist: String, title: String, album: String)?
    private let metadataResolver = TrackMetadataResolver(
        client: LastFmCatalogClient(apiKey: Secrets.lastFmApiKey)
    )
    var isScrobbling: Bool = false
    var lastScrobbledTrack: String = ""
    var errorMessage: String?
    var musicAppStatus: String = "Connecting to Music app..."
    /// Briefly set to true when a scrobble succeeds, then reset after a delay
    var showScrobbleSuccess: Bool = false
    /// Number of scrobbles waiting to be retried
    var pendingRetryCount: Int { failedScrobbles.count }

    private var lastScrobbleTime: Date?
    private let minimumScrobbleInterval: TimeInterval = 30
    private var pollTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?

    /// Queue of failed scrobbles to retry
    private var failedScrobbles: [(artist: String, title: String, album: String, timestamp: Date)] = []
    private static let maxRetryQueueSize = 50

    private var currentTrackStartTime: Date?
    private var currentTrackDuration: TimeInterval?
    private var scrobbleTask: Task<Void, Never>?
    private var hasScrobbledCurrentSession = false

    // Track auth monitoring tasks so we can cancel them when services refresh
    private var authMonitoringTasks: [Task<Void, Never>] = []

    // Activity token to prevent App Nap while music is playing
    private var backgroundActivityToken: NSObjectProtocol?

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
        self.setupScrobblingServices(preferencesManager: preferencesManager)
        
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
        setupWakeObserver()
        startPolling()

        // Initial check for now playing
        Task {
            await checkNowPlaying()
        }
    }
    
    private func startPreferencesObservation(_ prefManager: PreferencesManager) {
        // Recursive observation loop
        withObservationTracking {
            // Read the properties we care about to register dependency
            _ = prefManager.enableLastFm
            _ = prefManager.trackCompletionPercentageBeforeScrobble
            _ = prefManager.maxTrackCompletionScrobbleDelay
            _ = prefManager.useMaxTrackCompletionScrobbleDelay
        } onChange: { [weak self] in
            Log.debug("Scrobbler: Preferences changed, scheduling refresh")
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshScrobblingServices()
                // Re-register observation
                self.startPreferencesObservation(prefManager)
            }
        }
    }
    
    private func setupScrobblingServices(preferencesManager: PreferencesManager?) {
        // Cancel any existing auth monitoring tasks before creating new ones
        for task in authMonitoringTasks {
            task.cancel()
        }
        authMonitoringTasks.removeAll()

        scrobblingServices.removeAll()

        guard let prefManager = preferencesManager else { return }

        // Add Last.fm service if enabled
        if prefManager.enableLastFm {
            let lastFmService = LastFmServiceAdapter(lastFmManager: lastFmManager)
            scrobblingServices.append(lastFmService)
        }

        // Subscribe to authentication state changes for all services
        for service in scrobblingServices {
            let task = Task {
                for await _ in service.authStatus {
                    guard !Task.isCancelled else { break }
                    Log.debug("Service auth state changed: \(service.serviceName)", category: .auth)
                    self.servicesLastUpdated = Date()
                }
            }
            authMonitoringTasks.append(task)
        }

        // Trigger UI update
        self.servicesLastUpdated = Date()

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
        
        // Clear current track display immediately. Reset the raw key so the
        // next poll replaces the placeholder even for an unchanged track.
        self.currentTrack = "Switching to \(app.displayName)..."
        self.currentRawTrackKey = ""
        self.currentArtwork = nil
        
        // Switch the fetcher
        _mediaRemoteFetcher?.setTargetApp(app)
        
        // Update the status to reflect the change
        musicAppStatus = "Connected to \(app.displayName)"
        
        // Schedule multiple checks to ensure we catch the new app's state
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            Log.debug("First check after app switch", category: .scrobble)
            await checkNowPlaying()

            try? await Task.sleep(for: .seconds(0.5))
            Log.debug("Second check after app switch", category: .scrobble)
            await checkNowPlaying()

            try? await Task.sleep(for: .seconds(1.0))
            Log.debug("Final check after app switch", category: .scrobble)
            await checkNowPlaying()
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

    private func setupWakeObserver() {
        // Monitor when display/system wakes to immediately check playback state
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake(_:)),
            name: NSWorkspace.screensDidWakeNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(handleSystemWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        Log.debug("Wake observer setup complete", category: .scrobble)
    }

    @objc private func handleSystemWake(_ notification: Notification) {
        Log.debug("System wake detected, checking playback state", category: .scrobble)
        Task {
            await checkNowPlaying()
        }
    }

    // MARK: - Background Activity Management

    private func beginBackgroundActivity() {
        guard backgroundActivityToken == nil else { return }

        backgroundActivityToken = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .suddenTerminationDisabled],
            reason: "Scrobbling active music playback"
        )
        Log.debug("Background activity started - App Nap disabled", category: .scrobble)
    }

    private func endBackgroundActivity() {
        guard let token = backgroundActivityToken else { return }

        ProcessInfo.processInfo.endActivity(token)
        backgroundActivityToken = nil
        Log.debug("Background activity ended - App Nap re-enabled", category: .scrobble)
    }
    
    private func startPolling() {
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await checkNowPlaying()
            }
        }
    }
    
    @objc private func handleMusicPlayerNotification(_ notification: Notification) {
        Task {
            await checkNowPlaying()
        }
    }

    // This runs on every poll tick — only log state *transitions* (new
    // track, playback stopped), never the steady state, or the log becomes
    // unreadable within minutes.
    private func checkNowPlaying() async {
        if let trackInfo = getCurrentTrackInfoViaFetcher() {
            // Web sources (browsers) relay whatever the page put in the Media
            // Session API — clean known junk before anything downstream sees it.
            let track = TrackMetadataCleaner.cleanIfWebSource(
                title: trackInfo.name,
                artist: trackInfo.artist,
                album: trackInfo.album,
                bundleIdentifier: trackInfo.bundleIdentifier,
                applicationName: trackInfo.application
            )
            let trackString = "\(track.artist) - \(track.title)"

            // Music is playing - prevent App Nap
            beginBackgroundActivity()

            // Same-track detection compares the *cleaned* identity, not the
            // displayed one — async resolution may rewrite currentTrack
            // mid-play, and that must not read as a track change.
            let isSameTrack = trackString == currentRawTrackKey
            currentArtwork = trackInfo.artwork

            // Only update now playing status and setup scrobble timer if this is a new track
            if !isSameTrack {
                currentRawTrackKey = trackString
                currentTrack = trackString
                Log.debug("Now playing: \(trackString) [\(trackInfo.application)]", category: .scrobble)
                // Reset scrobble session flag for new track
                hasScrobbledCurrentSession = false

                setupScrobbleTimer(artist: track.artist, title: track.title, album: track.album)

                resolveWebMetadata(
                    for: track,
                    rawKey: trackString,
                    isWebSource: TrackMetadataCleaner.isWebSource(
                        bundleIdentifier: trackInfo.bundleIdentifier,
                        applicationName: trackInfo.application
                    )
                )

                // Keep the suspension last. A stale continuation that resumes
                // here after a track change must not touch shared state.
                await updateNowPlaying(artist: track.artist, title: track.title, album: track.album)
            }
        } else {
            if currentTrack != "No track playing" {
                Log.debug("Playback stopped, invalidating scrobble timers", category: .scrobble)
                currentTrack = "No track playing"
                currentRawTrackKey = ""
                currentArtwork = nil
                resolutionTask?.cancel()
                resolutionTask = nil
                invalidateScrobbleTimer()

                // Music stopped - allow App Nap again
                endBackgroundActivity()
            }
        }
    }

    // MARK: - Web Metadata Resolution

    /// Kicks off async Last.fm confirmation of an embedded-artist split for
    /// web tracks ("VNRD" uploading "Distant Strangers - Do Anything").
    /// Fire-and-forget: failure or no-match leaves the cleaned fields as-is.
    private func resolveWebMetadata(
        for track: (title: String, artist: String, album: String),
        rawKey: String,
        isWebSource: Bool
    ) {
        resolutionTask?.cancel()
        resolutionTask = nil
        guard isWebSource else { return }

        resolutionTask = Task { [weak self] in
            guard let self else { return }
            let outcome = await self.metadataResolver.resolve(title: track.title, artist: track.artist)
            guard case .confirmed(let resolved) = outcome else { return }
            self.applyResolvedMetadata(resolved, rawKey: rawKey, fallbackAlbum: track.album)
        }
    }

    private func applyResolvedMetadata(
        _ resolved: TrackMetadataResolver.ResolvedTrack,
        rawKey: String,
        fallbackAlbum: String
    ) {
        // The track may have changed while we were resolving.
        guard currentRawTrackKey == rawKey else { return }

        let album = resolved.album ?? fallbackAlbum
        Log.info("Resolved web metadata: \(resolved.artist) - \(resolved.title)", category: .scrobble)

        currentTrack = "\(resolved.artist) - \(resolved.title)"
        // The pending scrobble timer reads this at fire time.
        pendingScrobbleMetadata = (artist: resolved.artist, title: resolved.title, album: album)

        Task {
            // The track can change before this task runs. Re-check so a stale
            // update cannot overwrite the newer track's now-playing status.
            guard currentRawTrackKey == rawKey else { return }
            await updateNowPlaying(artist: resolved.artist, title: resolved.title, album: album)
        }
    }
    

    // Called from the poll loop — must stay silent in the steady state.
    private func getCurrentTrackInfoViaFetcher() -> (name: String, artist: String, album: String, duration: TimeInterval?, application: String, bundleIdentifier: String?, artwork: NSImage?)? {
        guard let fetcher = _mediaRemoteFetcher else {
            return nil
        }

        let trackInfo = fetcher.fetchCurrentTrackInfo()

        guard trackInfo.isPlaying, !trackInfo.title.isEmpty, !trackInfo.artist.isEmpty else {
            return nil
        }
        return (name: trackInfo.title, artist: trackInfo.artist, album: trackInfo.album, duration: trackInfo.duration, application: trackInfo.application, bundleIdentifier: trackInfo.bundleIdentifier, artwork: trackInfo.artwork)
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
                    let serviceName = service.serviceName
                    group.addTask {
                        do {
                            let result = try await service.scrobble(artist: artist, track: title, album: album)
                            return (serviceName, result)
                        } catch {
                            Log.error("Scrobble error for \(serviceName): \(error)", category: .scrobble)
                            return (serviceName, false)
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

                self.isScrobbling = false

                if !successes.isEmpty {
                    self.lastScrobbledTrack = "\(artist) - \(title)"
                    self.showScrobbleSuccess = true
                    Log.debug("Successfully scrobbled to: \(successes.joined(separator: ", "))", category: .scrobble)
                    // Reset success indicator after 2 seconds
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        self.showScrobbleSuccess = false
                    }
                    // Successful scrobble — try to flush retry queue
                    self.processRetryQueue()
                }

                if !failures.isEmpty {
                    let failureNames = failures.joined(separator: ", ")
                    Log.error("Failed to scrobble to: \(failureNames)", category: .scrobble)

                    // If ALL services failed, queue for retry
                    if successes.isEmpty {
                        self.queueFailedScrobble(artist: artist, title: title, album: album)
                        self.errorMessage = "Failed to scrobble — will retry (\(self.failedScrobbles.count) queued)"
                    } else {
                        self.errorMessage = "Failed to scrobble to: \(failureNames)"
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

            // Calculate when to scrobble
            // use preference value for track completion percentage before scrobble
            let completionPercentage = preferencesManager?.trackCompletionPercentageBeforeScrobble ?? 50 // half time fallback
            let percentageDelay = duration * Double(completionPercentage) / 100.0
            
            
            let scrobbleDelay: Double
            // support unresctricted max delay if preference is set to nil
            if preferencesManager?.useMaxTrackCompletionScrobbleDelay == true,
               let maxDelay = preferencesManager?.maxTrackCompletionScrobbleDelay {
                scrobbleDelay = min(percentageDelay, Double(maxDelay))
            } else {
                scrobbleDelay = percentageDelay
            }
            
            Log.debug("Will scrobble after \(scrobbleDelay) seconds", category: .scrobble)

            pendingScrobbleMetadata = (artist: artist, title: title, album: album)

            // Use Task.sleep instead of Timer for modern Swift concurrency.
            // Metadata is read at fire time, not captured — async web
            // resolution may have corrected it mid-play.
            scrobbleTask = Task {
                do {
                    try await Task.sleep(for: .seconds(scrobbleDelay))
                    // The sleep can return before a late cancel lands. Do not
                    // read pendingScrobbleMetadata for a cancelled timer — it
                    // may already hold the next track.
                    guard !Task.isCancelled else { return }
                    Log.debug("Scrobble timer fired", category: .scrobble)
                    let metadata = pendingScrobbleMetadata ?? (artist: artist, title: title, album: album)
                    scrobbleTrack(artist: metadata.artist, title: metadata.title, album: metadata.album)
                } catch {
                    // Cancelled — track changed or stopped, do nothing
                    Log.debug("Scrobble timer cancelled", category: .scrobble)
                }
            }
        } else {
            Log.error("Could not get track duration", category: .scrobble)
        }
    }

    private func invalidateScrobbleTimer() {
        scrobbleTask?.cancel()
        scrobbleTask = nil
        pendingScrobbleMetadata = nil
        currentTrackStartTime = nil
        currentTrackDuration = nil
        // Reset session flag when track stops/changes
        hasScrobbledCurrentSession = false
    }
    
    private func updateNowPlaying(artist: String, title: String, album: String) async {
        // Update now playing for all enabled services
        await withTaskGroup(of: (String, Bool).self) { group in
            for service in self.scrobblingServices {
                let serviceName = service.serviceName
                group.addTask {
                    do {
                        let result = try await service.updateNowPlaying(artist: artist, track: title, album: album)
                        return (serviceName, result)
                    } catch {
                        Log.error("Now playing error for \(serviceName): \(error)", category: .scrobble)
                        return (serviceName, false)
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
    
    // MARK: - Retry Queue

    private func queueFailedScrobble(artist: String, title: String, album: String) {
        let entry = (artist: artist, title: title, album: album, timestamp: Date.now)

        // Cap the queue to prevent unbounded growth
        if failedScrobbles.count >= Self.maxRetryQueueSize {
            failedScrobbles.removeFirst()
        }
        failedScrobbles.append(entry)
        Log.debug("Queued failed scrobble: \(artist) - \(title) (\(failedScrobbles.count) in queue)", category: .scrobble)
    }

    private func processRetryQueue() {
        guard !failedScrobbles.isEmpty else { return }

        let pending = failedScrobbles
        failedScrobbles.removeAll()
        Log.debug("Retrying \(pending.count) queued scrobbles", category: .scrobble)

        retryTask?.cancel()
        retryTask = Task {
            for entry in pending {
                guard !Task.isCancelled else {
                    // Re-queue remaining entries
                    failedScrobbles.append(contentsOf: pending.suffix(from: pending.firstIndex(where: { $0.timestamp == entry.timestamp }) ?? pending.endIndex))
                    break
                }

                var anySuccess = false
                for service in self.scrobblingServices {
                    do {
                        let result = try await service.scrobble(artist: entry.artist, track: entry.title, album: entry.album)
                        if result { anySuccess = true }
                    } catch {
                        Log.error("Retry scrobble failed for \(service.serviceName): \(error)", category: .scrobble)
                    }
                }

                if anySuccess {
                    Log.debug("Retry succeeded: \(entry.artist) - \(entry.title)", category: .scrobble)
                } else {
                    // Re-queue if all services still failing
                    queueFailedScrobble(artist: entry.artist, title: entry.title, album: entry.album)
                }

                // Small delay between retries to avoid hammering the API
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    isolated deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        pollTask?.cancel()
        scrobbleTask?.cancel()
        retryTask?.cancel()
        for task in authMonitoringTasks {
            task.cancel()
        }
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

