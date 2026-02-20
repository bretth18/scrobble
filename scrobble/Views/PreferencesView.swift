//
//  PreferencesView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI
import Observation

struct BillionsMustScrobbleView: View {
    var body: some View {
        Text("Billions must scrobble!")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

struct ScrobbleTimingSettingsView: View {
    @Environment(PreferencesManager.self) var preferencesManager

    var body: some View {
        @Bindable var preferencesManager = preferencesManager

        Section {
            Picker("Scrobble after", selection: $preferencesManager.trackCompletionPercentageBeforeScrobble) {
                Text("25% of track").tag(25)
                Text("50% of track").tag(50)
                Text("75% of track").tag(75)
                Text("90% of track").tag(90)
            }

            Toggle("Cap scrobble time for long tracks", isOn: $preferencesManager.useMaxTrackCompletionScrobbleDelay)

            if preferencesManager.useMaxTrackCompletionScrobbleDelay {
                Picker("Maximum time before scrobble", selection: $preferencesManager.maxTrackCompletionScrobbleDelay) {
                    Text("2 minutes").tag(120)
                    Text("4 minutes").tag(240)
                    Text("6 minutes").tag(360)
                    Text("8 minutes").tag(480)
                }
            }
        } header: {
            Text("Scrobble Timing")
        } footer: {
            Text("Adjust when tracks are scrobbled based on how much of the track has played.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct PreferencesView: View {
    @Environment(PreferencesManager.self) var preferencesManager
    @Environment(Scrobbler.self) var scrobbler
    @Environment(AuthState.self) var authState

    var body: some View {
        @Bindable var preferencesManager = preferencesManager

        Form {
            Section("About") {
                HStack {
                    Text("scrobble v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")")
                        .font(.headline)
                        .fontWeight(.bold)

                    Text("[build \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown")]")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Spacer()
                }

                BillionsMustScrobbleView()

                HStack {
                    Text("copyright \u{00A9} 2025-2026 COMPUTER DATA")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()

                    Link("GitHub", destination: URL(string: "https://github.com/bretth18/scrobble")!)
                        .font(.caption2)
                    Link("License", destination: URL(string: "https://github.com/bretth18/scrobble/blob/main/LICENSE")!)
                        .font(.caption2)
                }
            }

            UpdateSettingsView()

            Section("Display") {
                LabeledStepper("Friends displayed:", value: $preferencesManager.numberOfFriendsDisplayed, in: 1...10)

                LabeledStepper(
                    "Friend recent tracks",
                    value: $preferencesManager.numberOfFriendsRecentTracksDisplayed,
                    in: 1...20
                )
            }

            ScrobbleTimingSettingsView()

            LaunchAtLoginSettingsView()

            Section {
                ScrobblingServicesView()
            } header: {
                Text("Scrobbling Services")
            } footer: {
                Text("Credentials are stored securely on-device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Music App") {
                Picker("Music App Source", selection: $preferencesManager.selectedMusicApp) {
                    ForEach(SupportedMusicApp.allApps, id: \.self) { app in
                        Label(app.displayName, systemImage: app.icon)
                            .tag(app)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: preferencesManager.selectedMusicApp) { _, newApp in
                    scrobbler.setTargetMusicApp(newApp)
                }

                Text("Select which app to monitor for scrobbling")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = authState.authError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
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

    PreferencesView()
        .environment(prefManager)
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .environment(authState)
        .environment(UpdateChecker())
}
