//
//  ScrobblingServicesView.swift
//  scrobble
//
//  Created by Brett Henderson on 12/9/24.
//

import SwiftUI

struct ScrobblingServicesView: View {
    @Environment(PreferencesManager.self) var preferencesManager
    @Environment(Scrobbler.self) var scrobbler
    @Environment(AuthState.self) var authState

    var body: some View {
        @Bindable var preferencesManager = preferencesManager

        VStack(alignment: .leading, spacing: 16) {
            // Last.fm Service
            ServiceRow(
                title: "Last.fm",
                isEnabled: $preferencesManager.enableLastFm,
                status: lastFmStatus
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Last.fm Username", text: $preferencesManager.username)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
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
            }

            Divider()

            // Custom Scrobbler (Bluesky)
            ServiceRow(
                title: "ScrobbleProtocol",
                isEnabled: $preferencesManager.enableCustomScrobbler,
                status: customScrobblerStatus
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Bluesky Handle (e.g. computerdata.co)", text: $preferencesManager.blueskyHandle)
                        .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Authenticate with Bluesky") {
                            scrobbler.refreshScrobblingServices()

                            if let customService = scrobbler.getScrobblingServices().first(where: { $0.serviceId == "custom" }) {
                                Task {
                                    do {
                                        let success = try await customService.authenticate()
                                        Log.debug("Custom auth result: \(success)", category: .ui)
                                    } catch {
                                        Log.error("Custom auth failed: \(error)", category: .auth)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(preferencesManager.blueskyHandle.isEmpty)

                        if let customService = scrobbler.getScrobblingServices().first(where: { $0.serviceId == "custom" }) {
                            let _ = scrobbler.servicesLastUpdated
                            if customService.isAuthenticated {
                                Button("Sign Out") {
                                    customService.signOut()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }

                    Text("ScrobbleProtocol uses Bluesky OAuth authentication (atproto)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var lastFmStatus: ServiceStatus {
        switch (scrobbler.lastFmManager as? LastFmDesktopManager)?.authStatus ?? .unknown {
        case .authenticated:
            return .connected
        case .needsAuth:
            return .notConnected
        case .failed(_):
            return .failed
        case .unknown:
            return .checking
        }
    }

    private var customScrobblerStatus: ServiceStatus {
        if !preferencesManager.enableCustomScrobbler {
            return .disabled
        }

        let _ = scrobbler.servicesLastUpdated
        if let customService = scrobbler.getScrobblingServices().first(where: { $0.serviceId == "custom" }) {
            return customService.isAuthenticated ? .connected : .notConnected
        }
        return .disabled
    }
}

#Preview {
    let prefManager = PreferencesManager()
    let authState = AuthState()
    let lastFmManager = LastFmDesktopManager(
        apiKey: prefManager.apiKey,
        apiSecret: prefManager.apiSecret,
        username: prefManager.username,
        authState: authState
    )

    ScrobblingServicesView()
        .environment(prefManager)
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .environment(authState)
        .padding()
}
