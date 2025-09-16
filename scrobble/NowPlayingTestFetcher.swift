//
//  NowPlayingTestFetcher.swift
//  scrobble
//
//  Created by Brett Henderson on 9/15/25.
//

import Foundation
import MediaRemoteAdapter

final class NowPlayingFetcher {

    let mediaController = MediaController()
    
    var currentTrackDuration: TimeInterval = 0
    var currentTrackTitle: String = ""
    var currentTrackArtist: String = ""
    var currentTrackAlbum: String = ""
    var currentApplication: String = ""
    var currentArtwork: NSImage? = nil
    var currentArtworkBase64: String? = nil
    var isPlaying: Bool = false
    
    
    init() {
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
}
