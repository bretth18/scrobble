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

    @Published var currentTrack: String = "No track playing"
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

    
    init(lastFmManager: LastFmManagerType? = nil) {
        
        if let manager = lastFmManager {
            self.lastFmManager = manager
        } else {
            // This should never be hit in production since you're passing the manager in ScrobbleApp
            self.lastFmManager = LastFmManager(apiKey: "", apiSecret: "", username: "", password: "")
        }
        setupMusicAppObserver()
        startPolling()
        checkNowPlaying()
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
            
            if let trackInfo = self.getCurrentTrackInfo() {
                let trackString = "\(trackInfo.artist) - \(trackInfo.name)"
                print("Current track: \(trackString)")
                
                DispatchQueue.main.async {
                    // If we're getting the same track info, this is likely just a polling update
                    let isSameTrack = trackString == self.currentTrack
                    self.currentTrack = trackString
                    
                    // Always update now playing status
                    self.updateNowPlaying(artist: trackInfo.artist, title: trackInfo.name, album: trackInfo.album)
                    
                    // Only setup new scrobble timer if this is a new track
                    if !isSameTrack {
                        print("New track detected, setting up scrobble timer")
                        self.setupScrobbleTimer(artist: trackInfo.artist, title: trackInfo.name, album: trackInfo.album)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    if self.currentTrack != "No track playing" {
                        print("No track playing, invalidating timers")
                        self.currentTrack = "No track playing"
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
    
    private func scrobbleTrack(artist: String, title: String, album: String) {
        print("Attempting to scrobble: \(artist) - \(title)")
        isScrobbling = true
        errorMessage = nil
        
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
    }
    
    private func setupScrobbleTimer(artist: String, title: String, album: String) {
        invalidateScrobbleTimer()
        
        // Get the track duration
        if let trackInfo = getCurrentTrackInfo() {
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
    }
    
    private func updateNowPlaying(artist: String, title: String, album: String) {
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
