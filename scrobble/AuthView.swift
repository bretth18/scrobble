//
//  AuthView.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI
import Observation

struct AuthView: View {
    var lastFmManager: LastFmDesktopManager
    @Binding var isAuthWindowShown: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Group {
                switch lastFmManager.authStatus {
                case .unknown:
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Checking authentication status...")
                    
                case .needsAuth:
                    Text("Authentication Required")
                        .font(.headline)
                    Text("Click 'Authenticate' to connect with Last.fm")
                    
                case .authenticated:
                    Text("Successfully Authenticated!")
                        .font(.headline)
                    Text("You can close this window")
                    
                case .failed(let errorMessage):
                    Text("Authentication Failed")
                        .font(.headline)
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
            }
            .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                Button("Close") {
                    dismiss()
                    isAuthWindowShown = false
                }
                
                if case .needsAuth = lastFmManager.authStatus {
                    Button("Authenticate") {
                        lastFmManager.startAuth()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(lastFmManager.isAuthenticating)
                } else if case .authenticated = lastFmManager.authStatus {
                    Button("OK") {
                        dismiss()
                        isAuthWindowShown = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.top)
        }
        .padding()
        .frame(width: 300)
        .onChange(of: lastFmManager.authStatus) { _, state in
            if case .authenticated = state {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                    isAuthWindowShown = false
                }
            }
        }
    }
}

#Preview {
    let authState = AuthState()
    let manager = LastFmDesktopManager(apiKey: "", apiSecret: "", username: "", authState: authState)
    return AuthView(lastFmManager: manager, isAuthWindowShown: .constant(true))
}