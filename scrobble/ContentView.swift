//
//  ContentView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

struct ContentViewHeaderView: View {
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("SCROBBLE")
                .font(.system(.headline, design: .rounded))
                .fontWeight(.semibold)
            
            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary.opacity(0.7))
            
            Spacer()
        }
    }
}

struct ContentViewStatusCardView: View {
    let status: String
    
    var statusColor: Color {
        status.contains("Connected") ? .green.opacity(0.8) : .orange.opacity(0.8)
    }
    
    var statusIcon: String {
        status.contains("Connected") ? "wifi" : "wifi.slash"
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.caption)
                .foregroundStyle(statusColor)
                .frame(width: 16)
            
            Text("status:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()

            Text(status)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(statusColor)
                .lineLimit(1)
            
            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(in: .rect(cornerRadius: 8))
    }
}


struct ContentViewNowPlayingCardView: View {
    let currentTrack: String
    let currentArtwork: NSImage?
    let lastScrobbledTrack: String
    let artworkSize: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Now Playing", systemImage: "play.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary.opacity(0.7))
                
                HStack(spacing: 10) {
                    Group {
                        if let artwork = currentArtwork {
                            Image(nsImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                            
                        } else {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.quaternary)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .foregroundStyle(.tertiary)
                                }
                        }
                    }
                    .frame(width: artworkSize, height: artworkSize)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(currentTrack.isEmpty ? "No track playing" : currentTrack)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: artworkSize)
            }
            
            Divider()
                .opacity(0.3)
            
            VStack(alignment: .leading, spacing: 6) {
                Label("Last Scrobbled", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(lastScrobbledTrack.isEmpty ? "No recent scrobbles" : lastScrobbledTrack)
                    .font(.system(size: 11))
                    .foregroundStyle(.primary.opacity(0.8))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                if let artwork = currentArtwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 40)
                        .opacity(0.5)
                        .clipped()
                }
            }
        }
    }
}
    
    struct ContentView: View {
        @EnvironmentObject var scrobbler: Scrobbler
        @EnvironmentObject var preferencesManager: PreferencesManager
    
        @State private var showingPreferences = false
    
        private let contentWidth: CGFloat = 280
        private let artworkSize: CGFloat = 80
        private let cornerRadius: CGFloat = 10
    
        var body: some View {
            GlassEffectContainer(spacing: 10) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SCROBBLE")
                            .font(.headline)
                        Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                    
                    
//                    HStack {
//                        Text("status:")
//                            .font(.caption2.monospaced())
//                            .foregroundStyle(.secondary.opacity(0.7))
//                        Spacer()
//                        Text(scrobbler.musicAppStatus)
//                            .textCase(.lowercase)
//                            .font(.subheadline)
//                            .foregroundColor(scrobbler.musicAppStatus.contains("Connected") ? .green.opacity(0.8) : .red.opacity(0.8))
//                    }
//                    .padding()
//                    .glassEffect(in: .rect(cornerRadius: 8))
//                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Current Target App Display
                    HStack {
                        Label("monitoring:", systemImage: preferencesManager.selectedMusicApp.icon)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary.opacity(0.7))
                        Spacer()
                        Text(preferencesManager.selectedMusicApp.displayName.lowercased())
                            .font(.subheadline)
                            .foregroundColor(.accentColor.opacity(0.8))
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    VStack(alignment: .leading) {
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Now Playing:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary.opacity(0.7))
                            
                            Text(scrobbler.currentTrack)
                            
                            
                            if let currentArtwork = scrobbler.currentArtwork {
                                Image(nsImage: currentArtwork)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 100, height: 100)
                                    .cornerRadius(8)
                                    .glassEffect(.clear)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    //                .frame(minWidth: 200)
                    .padding()
                    .background {
                        if let currentArtwork = scrobbler.currentArtwork {
                            Image(nsImage: currentArtwork)
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 30)
                                .opacity(0.3)
                            
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
                .frame(maxWidth: .infinity)
                
                .padding()
            }
        }
    }
    
    
    
    
//    struct ContentView: View {
//        @EnvironmentObject var scrobbler: Scrobbler
//        @EnvironmentObject var preferencesManager: PreferencesManager
//        
//        @State private var showingPreferences = false
//        
//        // Define consistent sizing
//        private let contentWidth: CGFloat = 280
//        private let artworkSize: CGFloat = 80
//        private let cornerRadius: CGFloat = 10
//        
//        var body: some View {
//            VStack(alignment: .leading, spacing: 12) {
//                // Header Section
//                ContentViewHeaderView()
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                
//                // Status Section
//                ContentViewStatusCardView(status: scrobbler.musicAppStatus)
//                    .frame(width: contentWidth)
//                
//                // Now Playing Section
//                ContentViewNowPlayingCardView(
//                    currentTrack: scrobbler.currentTrack,
//                    currentArtwork: scrobbler.currentArtwork,
//                    lastScrobbledTrack: scrobbler.lastScrobbledTrack,
//                    artworkSize: artworkSize
//                )
//                .glassEffect(in: .rect(cornerRadius: cornerRadius))
//                .frame(width: contentWidth)
//                
//                // Loading/Error Section
//                if scrobbler.isScrobbling || scrobbler.errorMessage != nil {
//                    VStack(spacing: 8) {
//                        if scrobbler.isScrobbling {
//                            HStack {
//                                ProgressView()
//                                    .progressViewStyle(CircularProgressViewStyle())
//                                    .scaleEffect(0.8)
//                                Text("Scrobbling...")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//                            .frame(maxWidth: .infinity)
//                        }
//                        
//                        if let errorMessage = scrobbler.errorMessage {
//                            Text(errorMessage)
//                                .font(.caption)
//                                .foregroundColor(.red)
//                                .lineLimit(2)
//                                .frame(maxWidth: .infinity, alignment: .center)
//                                .padding(.horizontal, 8)
//                        }
//                    }
//                    .frame(width: contentWidth)
//                }
//            }
//            .padding(12)
//            .frame(width: contentWidth + 24) // Account for padding
//        }
//    }


#Preview {
    let prefManager = PreferencesManager()
    let lastFmManager = LastFmManager(
        apiKey: prefManager.apiKey,
        apiSecret: prefManager.apiSecret,
        username: prefManager.username,
        password: prefManager.password
    )
    ContentView()
        .environmentObject(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .environmentObject(prefManager)
}
