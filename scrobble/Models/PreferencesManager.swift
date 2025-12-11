//
//  PreferencesManager.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import AppKit

import Observation

@Observable
class PreferencesManager {
    // Standard access for secrets
    var apiKey: String { Secrets.lastFmApiKey }
    var apiSecret: String { Secrets.lastFmApiSecret }
    
    var username: String = "" {
        didSet { UserDefaults.standard.set(username, forKey: "lastFmUsername") }
    }
    
    var password: String = "" {
        didSet { UserDefaults.standard.set(password, forKey: "lastFmPassword") }
    }
    
    var numberOfFriendsDisplayed: Int = 10 {
        didSet { UserDefaults.standard.set(numberOfFriendsDisplayed, forKey: "numberOfFriendsDisplayed")}
    }
    
    var numberOfFriendsRecentTracksDisplayed: Int = 5 {
        didSet { UserDefaults.standard.set(numberOfFriendsRecentTracksDisplayed, forKey: "numberOfFriendsRecentTracksDisplayed")}
    }
    
    var selectedMusicApp: SupportedMusicApp = SupportedMusicApp.allApps.first(where: { $0.bundleId == "com.apple.Music" })! {
        didSet { 
            UserDefaults.standard.set(selectedMusicApp.bundleId, forKey: "selectedMusicAppBundleId")
            if _isInitialized {
                mediaAppSource = selectedMusicApp.displayName
            }
        }
    }
    
    // Scrobble configuration
    var trackCompletionPercentageBeforeScrobble: Int = 50 {
        didSet { UserDefaults.standard.set(trackCompletionPercentageBeforeScrobble, forKey: "trackCompletionPercentageBeforeScrobble") }
    }
    
    // default max delay of 240 seconds (4 minutes)
    
    var useMaxTrackCompletionScrobbleDelay: Bool = true {
        didSet {
            UserDefaults.standard.set(useMaxTrackCompletionScrobbleDelay, forKey: "useMaxTrackCompletionScrobbleDelay")
        }
    }
    var maxTrackCompletionScrobbleDelay: Int? = 240 {
        didSet { UserDefaults.standard.set(maxTrackCompletionScrobbleDelay, forKey: "maxTrackCompletionScrobbleDelay") }
    }
    
    // Keep for backwards compatibility
    var mediaAppSource: String = "Apple Music" {
        didSet { UserDefaults.standard.set(mediaAppSource, forKey: "mediaAppSource") }
    }
    
    // Custom scrobbler settings
    var enableCustomScrobbler: Bool = false {
        didSet { UserDefaults.standard.set(enableCustomScrobbler, forKey: "enableCustomScrobbler") }
    }
    
    var blueskyHandle: String = "" {
        didSet { UserDefaults.standard.set(blueskyHandle, forKey: "blueskyHandle") }
    }
    
    // Last.fm settings
    var enableLastFm: Bool = true {
        didSet { UserDefaults.standard.set(enableLastFm, forKey: "enableLastFm") }
    }
    
    private var _isInitialized = false
    
    init() {
        self.username = UserDefaults.standard.string(forKey: "lastFmUsername") ?? ""
        self.password = UserDefaults.standard.string(forKey: "lastFmPassword") ?? ""
        
        let savedShown = UserDefaults.standard.integer(forKey: "numberOfFriendsDisplayed")
        if savedShown > 0 {
            self.numberOfFriendsDisplayed = savedShown
        }
        
        let savedRecentTracks = UserDefaults.standard.integer(forKey: "numberOfFriendsRecentTracksDisplayed")
        if savedRecentTracks > 0 {
            self.numberOfFriendsRecentTracksDisplayed = savedRecentTracks
        }
        
        let savedCompletionPercentage = UserDefaults.standard.integer(forKey: "trackCompletionPercentageBeforeScrobble")
        if savedCompletionPercentage > 0 {
            self.trackCompletionPercentageBeforeScrobble = savedCompletionPercentage
        }
        
        let savedMaxDelay = UserDefaults.standard.integer(forKey: "maxTrackCompletionScrobbleDelay")
        if savedMaxDelay > 0 {
            self.maxTrackCompletionScrobbleDelay = savedMaxDelay
        }
        
        self.mediaAppSource = UserDefaults.standard.string(forKey: "mediaAppSource") ?? "Apple Music"
        
        self.enableCustomScrobbler = UserDefaults.standard.bool(forKey: "enableCustomScrobbler")
        self.blueskyHandle = UserDefaults.standard.string(forKey: "blueskyHandle") ?? ""
        
        // Initialize Last.fm settings
        if UserDefaults.standard.object(forKey: "enableLastFm") != nil {
            self.enableLastFm = UserDefaults.standard.bool(forKey: "enableLastFm")
        }
        
        let savedBundleId = UserDefaults.standard.string(forKey: "selectedMusicAppBundleId") ?? "com.apple.Music"
        self.selectedMusicApp = SupportedMusicApp.findApp(byBundleId: savedBundleId) ?? SupportedMusicApp.allApps.first(where: { $0.bundleId == "com.apple.Music" })!
        
        // Sync mediaAppSource
        if mediaAppSource != selectedMusicApp.displayName {
            mediaAppSource = selectedMusicApp.displayName
        }
        
        _isInitialized = true
    }
    
    func showPreferences() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "preferences" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func showMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
