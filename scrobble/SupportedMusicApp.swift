//
//  SupportedMusicApp.swift
//  scrobble
//
//  Created by Brett Henderson on 9/19/25.
//

import Foundation

struct SupportedMusicApp: Identifiable, Hashable, Codable {
    let id = UUID()
    let bundleId: String
    let displayName: String
    let alternativeNames: [String]
    let icon: String
    
    static let allApps: [SupportedMusicApp] = [
        SupportedMusicApp(
            bundleId: "com.apple.Music", 
            displayName: "Apple Music", 
            alternativeNames: ["Music", "Apple Music", "music", "Music.app", "Music.app (Music)", "AppleMusic"],
            icon: "music.note"
        ),
        SupportedMusicApp(
            bundleId: "com.spotify.client", 
            displayName: "Spotify", 
            alternativeNames: ["Spotify", "Spotify for Mac", "spotify"],
            icon: "music.note.list"
        ),
        SupportedMusicApp(
            bundleId: "com.apple.safari", 
            displayName: "Safari", 
            alternativeNames: ["Safari", "Safari.app", "safari", "Safari.app (Safari)"],
            icon: "globe"
        ),
        SupportedMusicApp(
            bundleId: "any", 
            displayName: "Any App", 
            alternativeNames: [],
            icon: "music.mic"
        )
    ]
    
    static func findApp(byBundleId bundleId: String) -> SupportedMusicApp? {
        return allApps.first { $0.bundleId == bundleId }
    }
    
    static func findApp(byName name: String) -> SupportedMusicApp? {
        return allApps.first { app in
            app.displayName.lowercased() == name.lowercased() ||
            app.alternativeNames.contains { $0.lowercased() == name.lowercased() }
        }
    }
    
    // Custom coding keys to exclude the id from persistence
    private enum CodingKeys: String, CodingKey {
        case bundleId, displayName, alternativeNames, icon
    }
}