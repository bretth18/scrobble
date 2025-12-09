//
//  AppSelectionView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/19/25.
//

import SwiftUI

struct AppSelectionView: View {
    @Environment(PreferencesManager.self) var preferencesManager
    @Environment(Scrobbler.self) var scrobbler
    @State private var runningApps: [SupportedMusicApp] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Music App")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            Text("Choose which app to monitor for scrobbling:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(SupportedMusicApp.allApps, id: \.self) { app in
                    AppSelectionButton(
                        app: app,
                        isSelected: app == preferencesManager.selectedMusicApp,
                        isRunning: runningApps.contains(app)
                    ) {
                        preferencesManager.selectedMusicApp = app
                        scrobbler.setTargetMusicApp(app)
                    }
                }
            }
            .padding(.horizontal)

            if !runningApps.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                        Text("Currently Running")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(runningApps.map { $0.displayName }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)
                    Text("Current Selection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: preferencesManager.selectedMusicApp.icon)
                        .foregroundStyle(Color.accentColor)
                        .aspectRatio(contentMode: .fill)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(preferencesManager.selectedMusicApp.displayName)
                            .font(.body)
                            .fontWeight(.medium)

                        if !preferencesManager.selectedMusicApp.alternativeNames.isEmpty {
                            Text("Also recognizes: \(preferencesManager.selectedMusicApp.alternativeNames.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2, reservesSpace: true)
                        }
                    }

                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .glassEffect(in: .rect(cornerRadius: 8))
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateRunningApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didActivateApplicationNotification)) { _ in
            updateRunningApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            updateRunningApps()
        }
    }
    
    private func updateRunningApps() {
        if let fetcher = scrobbler.mediaRemoteFetcher {
            runningApps = fetcher.getRunningMusicApps()
        }
    }
}

struct AppSelectionButton: View {
    let app: SupportedMusicApp
    let isSelected: Bool
    let isRunning: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Image(systemName: app.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .primary)
                    
                    if isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 12, y: -12)
                    }
                }
                
                Text(app.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)

        }
        .buttonStyle(isSelected ? .glass(.identity.tint(.accentColor)) : .glass)
        .tint(isSelected ? .accentColor : .none)
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
    AppSelectionView()
        .environment(prefManager)
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
}
