//
//  MainView.swift
//  scrobble
//
//  Created by Brett Henderson on 1/2/25.
//

import SwiftUI

struct MainView: View {
    @EnvironmentObject var scrobbler: Scrobbler
    @EnvironmentObject var preferencesManager: PreferencesManager
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Scrobbling", systemImage: "music.note")
                }
            
            FriendsView(lastFmManager: scrobbler.lastFmManager)
                .tabItem {
                    Label("Friends", systemImage: "person.2")
                }
        }
        .frame(minWidth: 300, minHeight: 400)
    }
}
#Preview {
    let prefManager = PreferencesManager()
    let lastFmManager = LastFmManager(
        apiKey: prefManager.apiKey,
        apiSecret: prefManager.apiSecret,
        username: prefManager.username,
        password: prefManager.password
    )
    MainView()
        .environmentObject(Scrobbler(lastFmManager: lastFmManager))
        .environmentObject(prefManager)
}
