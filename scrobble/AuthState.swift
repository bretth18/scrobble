//
//  AuthState.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import SwiftUI
import Combine
import Observation

@Observable
class AuthState {
    var isAuthenticated = false
    var isAuthenticating = false
    var showingAuthSheet = false
    var authError: String?
    
    init() {
        // Check for existing session on launch
        isAuthenticated = UserDefaults.standard.string(forKey: "lastfm_session_key") != nil
    }
    
    func startAuth() {
        showingAuthSheet = true
        isAuthenticating = true
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
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
        isAuthenticated = false
        authError = nil
    }
}

