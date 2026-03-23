//
//  ScrobblingView.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

struct ScrobblingView: View {
    @Environment(Scrobbler.self) var scrobbler
    @Environment(PreferencesManager.self) var preferencesManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSection) {
            HStack {
                Text("SCROBBLE")
                    .font(.headline)
                Text(
                    "v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.top)

            // Current Target App Display
            HStack {
                Label(
                    "monitoring:",
                    systemImage: preferencesManager.selectedMusicApp.icon
                )
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                Spacer()
                Text(
                    preferencesManager.selectedMusicApp.displayName
                        .lowercased()
                )
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Scrobbling Services Status
            VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
                Text("scrobbling to:")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)

                ServicesStatusView()
                    .environment(scrobbler)
            }
            .padding()
            .compatGlass(cornerRadius: DesignTokens.cornerRadiusMedium)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading) {
                VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
                    Text("Now Playing:")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)

                    MarqueeText(
                        text: scrobbler.currentTrack,
                        font: .body
                    )

                    if let currentArtwork = scrobbler.currentArtwork {
                        Image(nsImage: currentArtwork)
                            .resizable()
                            .scaledToFit()
                            .frame(
                                width: DesignTokens.artworkSizeSmall,
                                height: DesignTokens.artworkSizeSmall
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall))
                            .shadow(radius: 2)
                            .accessibilityLabel("Album artwork")
                    } else {
                        RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall)
                            .fill(.quaternary)
                            .frame(
                                width: DesignTokens.artworkSizeSmall,
                                height: DesignTokens.artworkSizeSmall
                            )
                            .overlay {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.tertiary)
                            }
                            .accessibilityHidden(true)
                    }

                    HStack(spacing: DesignTokens.spacingTight) {
                        Text("Last Scrobbled:")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)

                        if scrobbler.showScrobbleSuccess {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.easeInOut(duration: 0.3), value: scrobbler.showScrobbleSuccess)

                    MarqueeText(
                        text: scrobbler.lastScrobbledTrack,
                        font: .body
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background {
                if let currentArtwork = scrobbler.currentArtwork {
                    Image(nsImage: currentArtwork)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 30)
                        .opacity(0.3)
                }
            }
            .compatGlass(cornerRadius: DesignTokens.cornerRadiusMedium)
            .padding(.horizontal)

            if scrobbler.isScrobbling {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.horizontal)
            }

            if let errorMessage = scrobbler.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    ScrobblingView()
        .environment(
            Scrobbler(
                lastFmManager: lastFmManager,
                preferencesManager: prefManager
            )
        )
        .environment(prefManager)
}
