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
                    TextField("API Key", text: $preferencesManager.apiKey)
                    SecureField("API Secret", text: $preferencesManager.apiSecret)
                    TextField("Username", text: $preferencesManager.username)
                    
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
                            Button("Connect to Last.fm") {
                                if let manager = scrobbler.lastFmManager as? LastFmDesktopManager {
                                    manager.startAuth()
                                }
                            }
                            .buttonStyle(.borderedProminent)
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
