//
//  NowPlayingTestFetcher.swift
//  scrobble
//
//  Created by Brett Henderson on 9/15/25.
//

import Foundation
import MediaRemoteAdapter

struct KnownMusicBundleIds: Hashable {
    static let spotify = "com.spotify.client"
    static let appleMusic = "com.apple.music"
    static let safari = "com.apple.safari"
}

struct KnownMusicAppNames: Hashable {
    static let spotify = ("Spotify", "Spotify for Mac", "spotify")
    static let appleMusic = ("Music" ,"Apple Music" ,"music" ,"Music.app" ,"Music.app (Music)" ,"AppleMusic")
    static let safari = ("Safari" ,"Safari.app" ,"safari" , "Safari.app (Safari)")
}

final class NowPlayingFetcher {

    var mediaController: MediaController
    
    var currentTrackDuration: TimeInterval = 0
    var currentTrackTitle: String = ""
    var currentTrackArtist: String = ""
    var currentTrackAlbum: String = ""
    var currentApplication: String = ""
    var currentArtwork: NSImage? = nil
    var currentArtworkBase64: String? = nil
    var isPlaying: Bool = false
    
    
    init(bundleId: String? = nil) {
        mediaController = MediaController(bundleIdentifier: bundleId)
        mediaController.onTrackInfoReceived = { trackInfo in
            self.currentTrackDuration = (trackInfo.payload.durationMicros ?? 0) / 1_000_000
            self.currentTrackTitle = trackInfo.payload.title!
            self.currentTrackArtist = trackInfo.payload.artist!
            self.currentTrackAlbum = trackInfo.payload.album!
            self.currentApplication = trackInfo.payload.applicationName!
            self.currentArtwork = trackInfo.payload.artwork
            self.currentArtworkBase64 = trackInfo.payload.artworkDataBase64
            self.isPlaying = trackInfo.payload.isPlaying ?? false
            
            
        }
    }
    
    func setOnTrackInfoReceived(_ callback: @escaping (TrackInfo) -> Void) {
        mediaController.onTrackInfoReceived = callback
    }
    
    
    func reloadWithNewBundleId(_ bundleId: String) {
        mediaController.stop()
        mediaController = MediaController(bundleIdentifier: bundleId)
        setupAndStart()
    }
    
    func setupAndStart() {
        mediaController.startListening()
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
    
    deinit {
        mediaController.stop()
    }
}
