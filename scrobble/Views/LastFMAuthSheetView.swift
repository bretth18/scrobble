//
//  LastFMAuthSheetView.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI
import WebKit
import Observation

struct LastFMAuthSheetView: View {
    var lastFmManager: LastFmDesktopManager
    @Environment(AuthState.self) var authState

    var body: some View {
        VStack(spacing: 0) {
            if authState.isAuthenticating {
                VStack(spacing: 20) {
                    Text("Last.fm Authentication")
                        .font(.headline)

                    ProgressView("Getting session...")
                        .progressViewStyle(.circular)

                    Text("Requesting session from Last.fm...\nThis may take a few seconds.")
                        .font(.caption)
                        .multilineTextAlignment(.center)

                    Button("Cancel", role: .cancel) {
                        authState.isAuthenticating = false
                        lastFmManager.completeAuthorization(authorized: false)
                    }

                    if let error = authState.authError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            } else {
                if #available(macOS 26, *) {
                    LastFMWebAuthView(lastFmManager: lastFmManager)
                        .environment(authState)
                } else {
                    LastFMWebAuthViewLegacy(lastFmManager: lastFmManager)
                        .environment(authState)
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

#Preview {
    let authState = AuthState()
    let manager = LastFmDesktopManager(apiKey: "", apiSecret: "", username: "", password: "", authState: authState)
    return LastFMAuthSheetView(lastFmManager: manager)
        .environment(authState)
}
