//
//  LastFMAuthSheetView.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI
import WebKit

struct LastFmAuthSheet: View {
    @ObservedObject var lastFmManager: LastFmDesktopManager
    @EnvironmentObject var authState: AuthState
    
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
                    
                    Button("Cancel") {
                        authState.isAuthenticating = false
                        lastFmManager.completeAuthorization(authorized: false)
                    }
                    
                    if let error = authState.authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                .padding()
                .frame(width: 400, height: 200)
            } else {
                LastFmWebAuthView(lastFmManager: lastFmManager)
                    .environmentObject(authState)
            }
        }
    }
}

#Preview {
    LastFmAuthSheet(lastFmManager: LastFmDesktopManager(apiKey: "", apiSecret: "", username: "", password: ""))
        .environmentObject(AuthState.shared)
}