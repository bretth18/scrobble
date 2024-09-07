//
//  scrobbleApp.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

@main
struct scrobbleApp: App {
    @StateObject private var preferencesManager = PreferencesManager()
    @StateObject private var scrobbler: Scrobbler
    
    init() {
        let prefManager = PreferencesManager()
        _preferencesManager = StateObject(wrappedValue: prefManager)
        
        let lastFmManager = LastFmManager(
            apiKey: prefManager.apiKey,
            apiSecret: prefManager.apiSecret,
            username: prefManager.username,
            password: prefManager.password
        )
        _scrobbler = StateObject(wrappedValue: Scrobbler(lastFmManager: lastFmManager))
    }
    
    var body: some Scene {
        MenuBarExtra("Last.fm Scrobbler", systemImage: "music.note") {
            ContentView()
                .environmentObject(scrobbler)
                .environmentObject(preferencesManager)
        }
        .menuBarExtraStyle(.window)
        
        WindowGroup("Preferences") {
            PreferencesView()
                .environmentObject(preferencesManager)
        }
        .defaultSize(width: 300, height: 200)
    }
}
