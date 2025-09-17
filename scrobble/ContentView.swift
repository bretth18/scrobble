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
        VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("SCROBBLE")
                        .font(.headline)
                }

                
                HStack {
                    Text("status:")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary.opacity(0.7))
                    Text(scrobbler.musicAppStatus)
                        .font(.subheadline)
                        .foregroundColor(scrobbler.musicAppStatus.contains("Connected") ? .green.opacity(0.8) : .red.opacity(0.8))
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 8))
                
                
                VStack(alignment: .leading) {
                    Text("Now Playing:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.7))
                    HStack(alignment: .center) {

                        Text(scrobbler.currentTrack)
                            .font(.body)
                    }
                    
                    if let currentArtwork = scrobbler.currentArtwork {
                        Image(nsImage: currentArtwork)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                    }
                        
                    
                    Spacer()
                    
                    Text("Last Scrobbled:")
                        .font(.subheadline)
                        .foregroundStyle(.secondary.opacity(0.7))
                    
                    HStack(alignment: .center) {
                        Text(scrobbler.lastScrobbledTrack)
                            .font(.body)
                    }
                }
                .frame(minWidth: 200)
                .padding()
                .background {
                    if let currentArtwork = scrobbler.currentArtwork {
                        Image(nsImage: currentArtwork)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 20)
                            .opacity(0.5)
                            
                    }
                }
                .glassEffect(in: .rect(cornerRadius: 8))

                
                if scrobbler.isScrobbling {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                
                if let errorMessage = scrobbler.errorMessage {
                    
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
            }
            .padding()
        }
}

#Preview {
    ContentView().environmentObject(Scrobbler())
}
