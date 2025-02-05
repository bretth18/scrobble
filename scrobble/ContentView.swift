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
                HStack {
                    Text("SCROBBLE")
                        .font(.headline)
                }

                
                HStack {
                    Text("Status:")
                        .font(.caption2)
                    Text(scrobbler.musicAppStatus)
                        .font(.subheadline)
                        .foregroundColor(scrobbler.musicAppStatus.contains("Connected") ? .green : .red)
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.ultraThinMaterial)
                }
                
                
                VStack(alignment: .leading) {
                    HStack(alignment: .center) {
                        Text("Now Playing:")
                            .font(.subheadline)
                        Text(scrobbler.currentTrack)
                            .font(.body)
                    }
                    
                    Spacer()
                    
                    HStack(alignment: .center) {
                        Text("Last Scrobbled:")
                            .font(.subheadline)
                        Text(scrobbler.lastScrobbledTrack)
                            .font(.body)
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .foregroundStyle(.ultraThickMaterial)
                        .shadow(radius: 1)
                }
                
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
        }
}

#Preview {
    ContentView().environmentObject(Scrobbler())
}
