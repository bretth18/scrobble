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
            Tab("Scrobbling", systemImage: "music.note") {
                ScrobblingView()
            }

            Tab("Apps", systemImage: "app.badge") {
                AppSelectionView()
            }

            Tab("Friends", systemImage: "person.2") {
                FriendsView(lastFmManager: scrobbler.lastFmManager)
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
