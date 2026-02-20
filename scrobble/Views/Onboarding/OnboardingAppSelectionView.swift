//
//  OnboardingAppSelectionView.swift
//  scrobble
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

struct OnboardingAppSelectionView: View {
    @Environment(PreferencesManager.self) var preferencesManager
    @Environment(Scrobbler.self) var scrobbler
    @State private var runningApps: [SupportedMusicApp] = []

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "music.note.tv")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                Text("Choose Your Music App")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select which app you use to play music. Scrobble will monitor this app for playback.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.contentPaddingHorizontal)
            }

            // App selection grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(SupportedMusicApp.allApps, id: \.self) { app in
                    OnboardingAppButton(
                        app: app,
                        isSelected: app == preferencesManager.selectedMusicApp,
                        isRunning: runningApps.contains(app)
                    ) {
                        preferencesManager.selectedMusicApp = app
                        scrobbler.setTargetMusicApp(app)
                    }
                }
            }
            .padding(.horizontal, DesignTokens.contentPaddingHorizontal)

            // Running apps indicator
            if !runningApps.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text("Running: \(runningApps.map { $0.displayName }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Current selection info
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: preferencesManager.selectedMusicApp.icon)
                        .foregroundStyle(Color.accentColor)
                    Text("Selected: \(preferencesManager.selectedMusicApp.displayName)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                if !preferencesManager.selectedMusicApp.alternativeNames.isEmpty &&
                   preferencesManager.selectedMusicApp.bundleId != "any" {
                    Text("Also recognizes: \(preferencesManager.selectedMusicApp.alternativeNames.prefix(3).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.bottom, 8)
        }
        .padding()
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

struct OnboardingAppButton: View {
    let app: SupportedMusicApp
    let isSelected: Bool
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: app.icon)
                        .font(.title)
                        .foregroundStyle(isSelected ? .white : .primary)

                    if isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 14, y: -14)
                    }
                }

                Text(app.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingLarge)
            .padding(.horizontal, DesignTokens.spacingSection)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge)
                    .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge)
                    .strokeBorder(isSelected ? Color.clear : Color.secondary.opacity(0.2), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
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

    OnboardingAppSelectionView()
        .environment(prefManager)
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .frame(width: 500, height: 450)
}
