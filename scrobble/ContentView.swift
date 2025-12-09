//
//  ContentView.swift
//  scrobble
//
//  Created by Brett Henderson on 1/2/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(Scrobbler.self) var scrobbler
    @Environment(PreferencesManager.self) var preferencesManager
    
    var body: some View {
        TabView {
            ScrobblingView()
                .tabItem {
                    Label("Scrobbling", systemImage: "music.note")
                }
            
            AppSelectionView()
                .tabItem {
                    Label("Apps", systemImage: "app.badge")
                }
            
            // Use type-safe casting to check for desktop manager
            if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                FriendsView(lastFmManager: desktopManager)
                    .tabItem {
                        Label("Friends", systemImage: "person.2")
                    }
            } else {
                FriendsView(lastFmManager: scrobbler.lastFmManager)
                    .tabItem {
                        Label("Friends", systemImage: "person.2")
                    }
            }
        }
        .tabViewStyle(.tabBarOnly)
        .frame(minWidth: 300, minHeight: 400)
    }
}
#Preview {
    let prefManager = PreferencesManager()
    let authState = AuthState()
    let lastFmManager = LastFmDesktopManager(
        apiKey: prefManager.apiKey,
        apiSecret: prefManager.apiSecret,
        username: prefManager.username,
        authState: authState
    )
    ContentView()
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .environment(prefManager)
}
