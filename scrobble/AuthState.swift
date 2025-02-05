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
    @Published var authError: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Check for existing session on launch
        isAuthenticated = UserDefaults.standard.string(forKey: "lastfm_session_key") != nil
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
        isAuthenticated = false
        authError = nil
    }
    
    func handleAuthSuccess() {
        isAuthenticated = true
        isAuthenticating = false
        authError = nil
    }
    
    func handleAuthFailure(_ error: String) {
        isAuthenticated = false
        isAuthenticating = false
        authError = error
    }
}

