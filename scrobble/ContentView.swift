//
//  ContentView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var scrobbler: Scrobbler
    @EnvironmentObject var preferencesManager: PreferencesManager

    @State private var showingPreferences = false
    
    var body: some View {
            VStack(spacing: 10) {
                Text("Last.fm Scrobbler")
                    .font(.headline)
                
                Text(scrobbler.musicAppStatus)
                    .font(.subheadline)
                    .foregroundColor(scrobbler.musicAppStatus.contains("Connected") ? .green : .red)
                
                Text("Now Playing:")
                    .font(.subheadline)
                Text(scrobbler.currentTrack)
                    .font(.body)
                
                Text("Last Scrobbled:")
                    .font(.subheadline)
                Text(scrobbler.lastScrobbledTrack)
                    .font(.body)
                
                if scrobbler.isScrobbling {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                
                if let errorMessage = scrobbler.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button("Open Preferences") {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
            .frame(width: 250)
        }
}

#Preview {
    ContentView().environmentObject(Scrobbler(lastFmManager: LastFmManager(apiKey: "", apiSecret: "", username: "", password: "")))
}
