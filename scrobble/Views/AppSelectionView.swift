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
        VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
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
            ], spacing: DesignTokens.spacingDefault) {
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
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                        .accessibilityHidden(true)
                    Text("Currently Running: ")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(runningApps.map { $0.displayName }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Divider()
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentColor)
                    Text("Current Selection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.spacingTight) {
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
                .padding(DesignTokens.spacingDefault)
                .compatGlass(cornerRadius: DesignTokens.cornerRadiusMedium)
            }
            .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            updateRunningApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { notification in
            if isMusicAppNotification(notification) {
                updateRunningApps()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { notification in
            if isMusicAppNotification(notification) {
                updateRunningApps()
            }
        }
    }

    private func updateRunningApps() {
        if let fetcher = scrobbler.mediaRemoteFetcher {
            runningApps = fetcher.getRunningMusicApps()
        }
    }

    private func isMusicAppNotification(_ notification: NotificationCenter.Publisher.Output) -> Bool {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else {
            return false
        }
        let musicBundleIds = SupportedMusicApp.allApps.map { $0.bundleId }.filter { $0 != "any" }
        return musicBundleIds.contains(bundleId)
    }
}

struct AppSelectionButton: View {
    let app: SupportedMusicApp
    let isSelected: Bool
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.spacingDefault) {
                ZStack {
                    Image(systemName: app.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .secondary)

                    if isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 12, y: -12)
                            .accessibilityHidden(true)
                    }
                }

                Text(app.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSection)
            .padding(.horizontal, DesignTokens.spacingDefault)
        }
        .compatGlassButtonStyle(selected: isSelected)
        .accessibilityLabel("\(app.displayName)\(isRunning ? ", running" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
