//
//  OnboardingPreferencesView.swift
//  scrobble
//
//  Created by Claude on 1/12/26.
//

import SwiftUI
import ServiceManagement

struct OnboardingPreferencesView: View {
    @Environment(PreferencesManager.self) var preferencesManager

    private let scrobblePercentages = [25, 50, 75, 90]
    private let maxDelayOptions = [120, 240, 360, 480]

    var body: some View {
        @Bindable var preferencesManager = preferencesManager

        VStack(spacing: 20) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)

                Text("Configure Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Set up how Scrobble tracks your listening. You can change these later in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.contentPaddingHorizontal)
            }

            // Settings form
            VStack(spacing: 16) {
                // Scrobble threshold
                PreferenceSection(title: "Scrobble After", icon: "percent") {
                    Picker("", selection: $preferencesManager.trackCompletionPercentageBeforeScrobble) {
                        ForEach(scrobblePercentages, id: \.self) { percentage in
                            Text("\(percentage)% of track").tag(percentage)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("A track is scrobbled after you've listened to this percentage.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Max delay
                PreferenceSection(title: "Maximum Wait Time", icon: "timer") {
                    Toggle("Cap scrobble delay", isOn: $preferencesManager.useMaxTrackCompletionScrobbleDelay)

                    if preferencesManager.useMaxTrackCompletionScrobbleDelay {
                        Picker("Max delay", selection: Binding(
                            get: { preferencesManager.maxTrackCompletionScrobbleDelay ?? 240 },
                            set: { preferencesManager.maxTrackCompletionScrobbleDelay = $0 }
                        )) {
                            ForEach(maxDelayOptions, id: \.self) { seconds in
                                Text("\(seconds / 60) minutes").tag(seconds)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Text("For long tracks, limit how long to wait before scrobbling.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Launch at login
                PreferenceSection(title: "Startup", icon: "power") {
                    Toggle("Launch Scrobble at login", isOn: $preferencesManager.launchAtLogin)
                        .onChange(of: preferencesManager.launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(newValue)
                        }

                    Text("Automatically start Scrobble when you log into your Mac.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, DesignTokens.contentPaddingHorizontal)

            Spacer()

            Text("You're all set! Click Complete Setup to start scrobbling.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding()
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.error("Failed to update launch at login: \(error)", category: .general)
        }
    }
}

struct PreferenceSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 20)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 6) {
                content
            }
            .padding(.leading, 26)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingPreferencesView()
        .environment(PreferencesManager())
        .frame(width: 500, height: 450)
}
