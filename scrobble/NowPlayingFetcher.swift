//
//  NowPlayingFetcher.swift
//  scrobble
//
//  Created by Brett Henderson on 9/15/25.
//

import Foundation
import MediaRemoteAdapter
import AppKit

struct KnownMusicBundleIds: Hashable {
    static let spotify = "com.spotify.client"
    static let appleMusic = "com.apple.Music"
    static let safari = "com.apple.safari"
}

struct KnownMusicAppNames: Hashable {
    static let spotify = ("Spotify", "Spotify for Mac", "spotify")
    static let appleMusic = ("Music" ,"Apple Music" ,"music" ,"Music.app" ,"Music.app (Music)" ,"AppleMusic")
    static let safari = ("Safari" ,"Safari.app" ,"safari" , "Safari.app (Safari)")
}

final class NowPlayingFetcher {

    private var mediaController: MediaController
    
    var currentTrackDuration: TimeInterval = 0
    var currentTrackTitle: String = ""
    var currentTrackArtist: String = ""
    var currentTrackAlbum: String = ""
    var currentApplication: String = ""
    var currentArtwork: NSImage? = nil
    var currentArtworkBase64: String? = nil
    var isPlaying: Bool = false
    
    // Track current target
    var currentTargetApp: SupportedMusicApp?
    
    // Store external callback to reapply after controller reset
    private var externalCallback: ((TrackInfo) -> Void)?
    
    init(bundleId: String? = nil) {
        // Find the app from our supported list
        if let bundleId = bundleId {
            currentTargetApp = SupportedMusicApp.findApp(byBundleId: bundleId)
        }
        
        mediaController = MediaController(bundleIdentifier: bundleId)
        setupTrackInfoHandler()
    }
    
    init(targetApp: SupportedMusicApp) {
        currentTargetApp = targetApp
        let bundleId = targetApp.bundleId == "any" ? nil : targetApp.bundleId
        mediaController = MediaController(bundleIdentifier: bundleId)
        setupTrackInfoHandler()
    }
    
    private func setupTrackInfoHandler() {
        mediaController.onTrackInfoReceived = { [weak self] trackInfo in
            guard let self = self else { return }
            
            // Update internal state
            self.currentTrackDuration = (trackInfo.payload.durationMicros ?? 0) / 1_000_000
            self.currentTrackTitle = trackInfo.payload.title ?? ""
            self.currentTrackArtist = trackInfo.payload.artist ?? ""
            self.currentTrackAlbum = trackInfo.payload.album ?? ""
            self.currentApplication = trackInfo.payload.applicationName ?? ""
            self.currentArtwork = trackInfo.payload.artwork
            self.currentArtworkBase64 = trackInfo.payload.artworkDataBase64
            self.isPlaying = trackInfo.payload.isPlaying ?? false
            
            // Call external callback if set
            self.externalCallback?(trackInfo)
        }
    }
    
    func setOnTrackInfoReceived(_ callback: @escaping (TrackInfo) -> Void) {
        externalCallback = callback
    }
    
    func setTargetApp(_ app: SupportedMusicApp) {
        Log.debug("Switching target app from \(currentTargetApp?.displayName ?? "none") to \(app.displayName)", category: .scrobble)
        
        // Immediately clear current state when switching apps
        clearCurrentState()
        
        // Stop everything immediately on main thread
        mediaController.stopListening()
        
        // Update target
        currentTargetApp = app
        let bundleId = app.bundleId == "any" ? nil : app.bundleId
        
        // Force a complete reload with a longer delay
        reloadWithNewBundleId(bundleId)
    }
    
    private func clearCurrentState() {
        Log.debug("Clearing current playback state", category: .scrobble)
        currentTrackDuration = 0
        currentTrackTitle = ""
        currentTrackArtist = ""
        currentTrackAlbum = ""
        currentApplication = ""
        currentArtwork = nil
        currentArtworkBase64 = nil
        isPlaying = false
    }
    
    func reloadWithNewBundleId(_ bundleId: String?) {
        Log.debug("Reloading MediaController with bundleId: \(bundleId ?? "nil (any app)")", category: .scrobble)
        
        // More aggressive cleanup - wait longer for complete termination
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            Log.debug("Creating new MediaController instance", category: .scrobble)
            
            // Create completely new controller instance
            self.mediaController = MediaController(bundleIdentifier: bundleId)
            
            // Reapply handlers
            self.setupTrackInfoHandler()
            
            // Start listening
            self.setupAndStart()
            
            Log.debug("MediaController reloaded and started for app: \(self.currentTargetApp?.displayName ?? "any")", category: .scrobble)
            
            // Force an immediate check after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                Log.debug("Current state after reload: \(self.getCurrentState())", category: .scrobble)
            }
        }
    }
    
    func setupAndStart() {
        Log.debug("Starting MediaController listening", category: .scrobble)
        mediaController.startListening()
    }
    
    func stop() {
        Log.debug("Stopping MediaController", category: .scrobble)
        mediaController.stopListening()
    }
    
    // Force an immediate update - useful after app switches
    func forceUpdate() {
        // This doesn't actually force an update from MediaController,
        // but we can trigger the UI to refresh by calling the callback with current state
        Log.debug("Forcing UI update with current state", category: .scrobble)
    }

    func fetchCurrentTrackInfo() -> (isPlaying: Bool, title: String, artist: String, album: String, duration: TimeInterval, application: String, artwork: NSImage?, artworkBase64: String?) {
        return (isPlaying: isPlaying, title: currentTrackTitle, artist: currentTrackArtist, album: currentTrackAlbum, duration: currentTrackDuration, application: currentApplication, artwork: currentArtwork, artworkBase64: currentArtworkBase64)
    }
    
    func fetchCurrentArtwork() -> NSImage? {
        return currentArtwork
    }
    
    func fetchCurrentArtworkBase64() -> String? {
        return currentArtworkBase64
    }
    
    func getCurrentlyPlayingApps() -> [String] {
        let runningApps = NSWorkspace.shared.runningApplications
        let musicAppBundleIds = SupportedMusicApp.allApps.map { $0.bundleId }.filter { $0 != "any" }
        
        return runningApps.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  musicAppBundleIds.contains(bundleId),
                  !app.isTerminated else { return nil }
            return SupportedMusicApp.findApp(byBundleId: bundleId)?.displayName
        }
    }
    
    func getRunningMusicApps() -> [SupportedMusicApp] {
        let runningApps = NSWorkspace.shared.runningApplications
        let musicAppBundleIds = SupportedMusicApp.allApps.map { $0.bundleId }.filter { $0 != "any" }
        
        return runningApps.compactMap { app in
            guard let bundleId = app.bundleIdentifier,
                  musicAppBundleIds.contains(bundleId),
                  !app.isTerminated else { return nil }
            return SupportedMusicApp.findApp(byBundleId: bundleId)
        }
    }
    
    // Debug method to check current state
    func getCurrentState() -> String {
        return """
        Target App: \(currentTargetApp?.displayName ?? "none")
        Bundle ID: \(currentTargetApp?.bundleId ?? "none")
        Is Playing: \(isPlaying)
        Current Track: \(currentTrackTitle)
        Current Artist: \(currentTrackArtist)
        Current App: \(currentApplication)
        """
    }
    
    deinit {
        mediaController.stopListening()
    }
}
