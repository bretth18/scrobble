//
//  PreferencesView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI
import Combine

struct PreferencesView: View {
    @EnvironmentObject var preferencesManager: PreferencesManager
    @EnvironmentObject var scrobbler: Scrobbler
    @EnvironmentObject var authState: AuthState
    
    @State private var cancellables = Set<AnyCancellable>()
    
    var body: some View {
        VStack() {
            

            
            Form {
                
                Section("About") {
                    
                    HStack(alignment: .center) {
                        Text("scrobbler v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("by COMPUTER DATA")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Billions must scrobble!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Display") {
                    Stepper(
                        "Friends shown: \(preferencesManager.numberOfFriendsDisplayed)",
                        value: $preferencesManager.numberOfFriendsDisplayed,
                        in: 1...10
                    )
                }
                
                Section("Scrobbling Services") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Last.fm Service
                        HStack {
                            Toggle("Enable Last.fm", isOn: $preferencesManager.enableLastFm)
                                .toggleStyle(.switch)
                            
                            Spacer()
                            
                            Group {
                                switch (scrobbler.lastFmManager as? LastFmDesktopManager)?.authStatus ?? .unknown {
                                case .authenticated:
                                    Label("Connected", systemImage: "checkmark.seal.fill")
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
                            .font(.caption)
                        }
                        
                        if preferencesManager.enableLastFm {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Last.fm Username", text: $preferencesManager.username)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack {
                                    if authState.isAuthenticated {
                                        Button("Sign Out") {
                                            if let manager = scrobbler.lastFmManager as? LastFmDesktopManager {
                                                manager.logout()
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                    } else {
                                        Button("Authenticate") {
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
                            .padding(.leading, 16)
                        }
                        
                        Divider()
                        
                        // Custom Scrobbling Service
                        HStack {
                            Toggle("Enable Custom Scrobbler", isOn: $preferencesManager.enableCustomScrobbler)
                                .toggleStyle(.switch)
                            
                            Spacer()
                            
                            // Show authentication status for custom scrobbler
                            if preferencesManager.enableCustomScrobbler {
                                let _ = scrobbler.servicesLastUpdated // Force refresh when services update
                                if let customService = scrobbler.getScrobblingServices().first(where: { $0.serviceId == "custom" }) {
                                    if customService.isAuthenticated {
                                        Label("Connected", systemImage: "checkmark.seal.fill")
                                            .foregroundStyle(.green)
                                    } else {
                                        Label("Not connected", systemImage: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.yellow)
                                    }
                                } else {
                                    Label("Disabled", systemImage: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        if preferencesManager.enableCustomScrobbler {
                            VStack(alignment: .leading, spacing: 4) {
                                TextField("Bluesky Handle (e.g. computerdata.co)", text: $preferencesManager.blueskyHandle)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack {
                                    Button("Authenticate with Bluesky") {
                                        // Refresh services first to ensure the custom service exists
                                        scrobbler.refreshScrobblingServices()
                                        
                                        // Then attempt authentication
                                        if let customService = scrobbler.getScrobblingServices().first(where: { $0.serviceId == "custom" }) {
                                            customService.authenticate()
                                                .sink(
                                                    receiveCompletion: { completion in
                                                        if case .failure(let error) = completion {
                                                            print("Custom auth failed: \(error)")
                                                        }
                                                    },
                                                    receiveValue: { success in
                                                        print("Custom auth result: \(success)")
                                                    }
                                                )
                                                .store(in: &cancellables) // You'll need to add this property
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(preferencesManager.blueskyHandle.isEmpty)
                                    
                                    if let customService = scrobbler.getScrobblingServices().first(where: { $0.serviceId == "custom" }) {
                                        let _ = scrobbler.servicesLastUpdated // Force refresh
                                        if customService.isAuthenticated {
                                            Button("Sign Out") {
                                                customService.signOut()
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                                
                                Text("Catalog Scrobbler uses Bluesky OAuth authentication (atproto)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 16)
                        }
                    }
                }
                
                Section("Music App") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Music App Source")
                            .font(.headline)
                        
                        Picker("Select Music App", selection: $preferencesManager.selectedMusicApp) {
                            ForEach(SupportedMusicApp.allApps, id: \.self) { app in
                                Label(app.displayName, systemImage: app.icon)
                                    .tag(app)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: preferencesManager.selectedMusicApp) { _, newApp in
                            // Update the scrobbler when the app selection changes
                            scrobbler.setTargetMusicApp(newApp)
                        }
                        
                        Text("Select which app to monitor for scrobbling")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    PreferencesView()
        .environmentObject(prefManager)
        .environmentObject(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
}

