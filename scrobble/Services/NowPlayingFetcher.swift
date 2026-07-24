//
//  NowPlayingFetcher.swift
//  scrobble
//

import Foundation
import MediaRemoteAdapter
import AppKit

@MainActor
final class NowPlayingFetcher {

    private let mediaController = MediaController()

    var currentTrackDuration: TimeInterval = 0
    var currentTrackTitle: String = ""
    var currentTrackArtist: String = ""
    var currentTrackAlbum: String = ""
    var currentApplication: String = ""
    var currentBundleIdentifier: String? = nil
    var currentArtwork: NSImage? = nil
    var currentArtworkBase64: String? = nil
    var isPlaying: Bool = false

    var currentTargetApp: SupportedMusicApp?

    init(bundleId: String? = nil) {
        if let bundleId {
            currentTargetApp = SupportedMusicApp.findApp(byBundleId: bundleId)
        }
        setupTrackInfoHandler()
    }

    init(targetApp: SupportedMusicApp) {
        currentTargetApp = targetApp
        setupTrackInfoHandler()
    }

    private func setupTrackInfoHandler() {
        // The adapter calls these on the main queue.
        mediaController.onTrackInfoReceived = { [weak self] trackInfo in
            self?.apply(trackInfo)
        }
        mediaController.onListenerTerminated = { [weak self] in
            Log.error("MediaRemote listener terminated, restarting", category: .scrobble)
            self?.mediaController.startListening()
        }
    }

    private func apply(_ trackInfo: TrackInfo?) {
        guard let payload = trackInfo?.payload else {
            clearCurrentState()
            return
        }
        // The adapter reports all apps. Ignore apps that are not the target.
        guard matchesTargetApp(payload.bundleIdentifier) else { return }

        currentTrackDuration = (payload.durationMicros ?? 0) / 1_000_000
        currentTrackTitle = payload.title ?? ""
        currentTrackArtist = payload.artist ?? ""
        currentTrackAlbum = payload.album ?? ""
        currentApplication = payload.applicationName ?? ""
        currentBundleIdentifier = payload.bundleIdentifier
        currentArtwork = payload.artwork
        currentArtworkBase64 = payload.artworkDataBase64
        isPlaying = payload.isPlaying ?? false
    }

    private func matchesTargetApp(_ bundleIdentifier: String?) -> Bool {
        guard let target = currentTargetApp, target.bundleId != "any" else { return true }
        guard let bundleIdentifier else { return false }
        return bundleIdentifier.lowercased() == target.bundleId.lowercased()
    }

    func setTargetApp(_ app: SupportedMusicApp) {
        Log.debug("Switching target app to \(app.displayName)", category: .scrobble)
        clearCurrentState()
        currentTargetApp = app
        // One-shot fetch so the new target shows without waiting for an event.
        mediaController.getTrackInfo { [weak self] trackInfo in
            self?.apply(trackInfo)
        }
    }

    private func clearCurrentState() {
        currentTrackDuration = 0
        currentTrackTitle = ""
        currentTrackArtist = ""
        currentTrackAlbum = ""
        currentApplication = ""
        currentBundleIdentifier = nil
        currentArtwork = nil
        currentArtworkBase64 = nil
        isPlaying = false
    }

    func fetchCurrentTrackInfo() -> (isPlaying: Bool, title: String, artist: String, album: String, duration: TimeInterval, application: String, bundleIdentifier: String?, artwork: NSImage?, artworkBase64: String?) {
        return (isPlaying: isPlaying, title: currentTrackTitle, artist: currentTrackArtist, album: currentTrackAlbum, duration: currentTrackDuration, application: currentApplication, bundleIdentifier: currentBundleIdentifier, artwork: currentArtwork, artworkBase64: currentArtworkBase64)
    }

    func setupAndStart() {
        mediaController.startListening()
    }

    func stop() {
        mediaController.stopListening()
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

    deinit {
        mediaController.stopListening()
    }
}
