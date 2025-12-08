//
//  PreferencesManager.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import AppKit

class PreferencesManager: ObservableObject {
    let apiKey = Secrets.lastFmApiKey
    let apiSecret = Secrets.lastFmApiSecret
    

    @Published var username: String {
        didSet { UserDefaults.standard.set(username, forKey: "lastFmUsername") }
    }
    @Published var password: String {
        didSet { UserDefaults.standard.set(password, forKey: "lastFmPassword") }
    }
    @Published var numberOfFriendsDisplayed: Int {
        didSet { UserDefaults.standard.set(numberOfFriendsDisplayed, forKey: "numberOfFriendsDisplayed")}
    }
    @Published var selectedMusicApp: SupportedMusicApp {
        didSet { 
            UserDefaults.standard.set(selectedMusicApp.bundleId, forKey: "selectedMusicAppBundleId")
            // Only sync with mediaAppSource after initialization is complete
            if _isInitialized {
                mediaAppSource = selectedMusicApp.displayName
            }
        }
    }
    
    // Keep for backwards compatibility
    @Published var mediaAppSource: String {
        didSet { UserDefaults.standard.set(mediaAppSource, forKey: "mediaAppSource") }
    }
    
    // Custom scrobbler settings
    @Published var enableCustomScrobbler: Bool {
        didSet { UserDefaults.standard.set(enableCustomScrobbler, forKey: "enableCustomScrobbler") }
    }
    
    @Published var blueskyHandle: String {
        didSet { UserDefaults.standard.set(blueskyHandle, forKey: "blueskyHandle") }
    }
    
    // Last.fm settings
    @Published var enableLastFm: Bool {
        didSet { UserDefaults.standard.set(enableLastFm, forKey: "enableLastFm") }
    }
    
    private var _isInitialized = false
    
    init() {
//        apiKey = UserDefaults.standard.string(forKey: "lastFmApiKey") ?? ""
//        apiSecret = UserDefaults.standard.string(forKey: "lastFmApiSecret") ?? ""
        username = UserDefaults.standard.string(forKey: "lastFmUsername") ?? ""
        password = UserDefaults.standard.string(forKey: "lastFmPassword") ?? ""
        numberOfFriendsDisplayed = UserDefaults.standard.integer(forKey: "numberOfFriendsDisplayed") ?? 3
        
        // Initialize mediaAppSource first to avoid initialization order issues
        mediaAppSource = UserDefaults.standard.string(forKey: "mediaAppSource") ?? "Apple Music"
        
        // Initialize custom scrobbler settings
        enableCustomScrobbler = UserDefaults.standard.bool(forKey: "enableCustomScrobbler")
        blueskyHandle = UserDefaults.standard.string(forKey: "blueskyHandle") ?? ""
        
        // Initialize Last.fm settings (default to enabled for backward compatibility)
        enableLastFm = UserDefaults.standard.object(forKey: "enableLastFm") != nil ? 
                       UserDefaults.standard.bool(forKey: "enableLastFm") : true
        
        // Then initialize selectedMusicApp
        let savedBundleId = UserDefaults.standard.string(forKey: "selectedMusicAppBundleId") ?? "com.apple.Music"
        selectedMusicApp = SupportedMusicApp.findApp(byBundleId: savedBundleId) ?? SupportedMusicApp.allApps.first(where: { $0.bundleId == "com.apple.Music" })!
        
        // Sync mediaAppSource with selectedMusicApp if they don't match
        if mediaAppSource != selectedMusicApp.displayName {
            mediaAppSource = selectedMusicApp.displayName
        }
        
        // Mark as initialized so didSet handlers work properly going forward
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
