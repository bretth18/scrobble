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
    @Published var currentTrack: String = "No track playing"
    @Published var isScrobbling: Bool = false
    @Published var lastScrobbledTrack: String = ""
    @Published var errorMessage: String?
    @Published var musicAppStatus: String = "Connecting to Music app..."
    
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.lastfm.scrobbler", qos: .background)
    private let lastFmManager: LastFmManager
    private var lastScrobbleTime: Date?
    private let minimumScrobbleInterval: TimeInterval = 30
    private var pollTimer: Timer?

    
    init(lastFmManager: LastFmManager? = nil) {
        self.lastFmManager = lastFmManager ?? LastFmManager(apiKey: "", apiSecret: "", username: "", password: "")

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
                    self.currentTrack = trackString
                    
                    if trackString != self.lastScrobbledTrack {
                        print("New track detected, attempting to scrobble")
                        self.scrobbleTrack(artist: trackInfo.artist, title: trackInfo.name, album: trackInfo.album)
                    } else {
                        print("Track hasn't changed, not scrobbling")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.currentTrack = "No track playing"
                }
            }
        }
    }
    
    private func getCurrentTrackInfo() -> (name: String, artist: String, album: String)? {
        let script = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set trackArtist to artist of current track
                set trackAlbum to album of current track
                return trackName & "|" & trackArtist & "|" & trackAlbum
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
        guard components.count == 3,
              !components[0].isEmpty,
              !components[1].isEmpty,
              !components[2].isEmpty else {
            return nil
        }
        
        return (name: components[0], artist: components[1], album: components[2])
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
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        pollTimer?.invalidate()
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
