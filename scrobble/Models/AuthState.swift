//
//  AuthState.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI

@Observable
@MainActor
class AuthState {
    var isAuthenticated = false
    var isAuthenticating = false
    var showingAuthSheet = false
    var authError: String?

    init() {
        // Check for existing session on launch (Keychain with UserDefaults fallback for migration)
        isAuthenticated = KeychainHelper.load(key: "lastfm_session_key") != nil
            || UserDefaults.standard.string(forKey: "lastfm_session_key") != nil
    }

    func startAuth() {
        // Don't show sheet yet - wait until token is obtained
        showingAuthSheet = false
        isAuthenticating = false  // WebView shows first; set to true only when requesting session
        authError = nil
    }

    func completeAuth(success: Bool) {
        showingAuthSheet = false
        isAuthenticating = false
        isAuthenticated = success
        if !success {
            authError = "Authentication failed or was cancelled"
        }
    }

    func signOut() {
        KeychainHelper.delete(key: "lastfm_session_key")
        KeychainHelper.delete(key: "lastfm_username")
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
        isAuthenticated = false
        authError = nil
    }
}
