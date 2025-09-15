//
//  PreferencesView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var scrobbler: Scrobbler
    @EnvironmentObject var authState: AuthState
    
    var body: some View {
        VStack {
            Form {
                Section("Last.fm API") {
                    Text("API Key: \(preferencesManager.apiKey)")
                    Text("API Secret: \(preferencesManager.apiSecret)")
                    TextField("Username", text: $preferencesManager.username)
                    
                    HStack(spacing: 8) {
                        Group {
                            switch (scrobbler.lastFmManager as? LastFmDesktopManager)?.authStatus ?? .unknown {
                            case .authenticated:
                                Label("Authenticated", systemImage: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            case .needsAuth:
                                Label("Not connected", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.yellow)
                            case .failed(let message):
                                Label("Auth failed", systemImage: "xmark.octagon.fill")
                                    .foregroundStyle(.red)
                            case .unknown:
                                Label("Checking...", systemImage: "hourglass")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.subheadline)

                        if case .failed(let message) = (scrobbler.lastFmManager as? LastFmDesktopManager)?.authStatus {
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    
                    HStack {
                        if authState.isAuthenticated {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            Button("Sign Out") {
                                if let manager = scrobbler.lastFmManager as? LastFmDesktopManager {
                                    manager.logout()
                                }
                            }
                        } else {
                            Button("Open Login Window") {
                                if let manager = scrobbler.lastFmManager as? LastFmDesktopManager {
                                    if manager.currentAuthToken.isEmpty {
                                        manager.startAuth()
                                    } else {
                                        authState.showingAuthSheet = true
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                
                Section("Display") {
                    Stepper(
                        "Friends shown: \(preferencesManager.numberOfFriendsDisplayed)",
                        value: $preferencesManager.numberOfFriendsDisplayed,
                        in: 1...10
                    )
                }
            }
            .formStyle(.grouped)
            
            if let error = authState.authError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding()
            }
            
            Text("Your credentials are stored securely on-device")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
    }
}

#Preview {
    PreferencesView()
        .environmentObject(PreferencesManager())   
}

