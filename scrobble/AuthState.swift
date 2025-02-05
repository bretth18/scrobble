//
//  AuthState.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import SwiftUI
import Combine

class AuthState: ObservableObject {
    static let shared = AuthState()
    
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var showingAuthSheet = false
    @Published var authError: String?
    
    private init() {
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

