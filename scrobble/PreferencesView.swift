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
    @StateObject private var authState = AuthState.shared
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Last.fm API").bold()) {
                    TextField("API Key", text: $preferencesManager.apiKey)
                        .textFieldStyle(.roundedBorder)
                    SecureField("API Secret", text: $preferencesManager.apiSecret)
                        .textFieldStyle(.roundedBorder)
                }
                
                Section(header: Text("Account").bold()) {
                    TextField("Username", text: $preferencesManager.username)
                        .textFieldStyle(.roundedBorder)
                    
                    if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                        HStack {
                            Button(authState.isAuthenticated ? "Log Out" : "Authenticate") {
                                if authState.isAuthenticated {
                                    authState.signOut()
                                    desktopManager.startAuth()
                                } else {
                                    desktopManager.startAuth()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            
                            if authState.isAuthenticated {
                                Text("✓ Connected")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Display").bold()) {
                    Stepper(
                        "Friends shown: \(preferencesManager.numberOfFriendsDisplayed)",
                        value: $preferencesManager.numberOfFriendsDisplayed,
                        in: 1...10
                    )
                }
            }
            .padding()
            .formStyle(.grouped)
            
            Text("Your credentials are stored securely on-device")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom)
        }
    }
}

#Preview {
    PreferencesView()
        .environmentObject(PreferencesManager())   
}
