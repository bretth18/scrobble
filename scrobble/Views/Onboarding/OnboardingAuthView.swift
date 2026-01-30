//
//  OnboardingAuthView.swift
//  scrobble
//
//  Created by Claude on 1/12/26.
//

import SwiftUI
import WebKit

struct OnboardingAuthView: View {
    @Environment(Scrobbler.self) var scrobbler
    @Environment(AuthState.self) var authState
    @State private var isAuthStarted = false

    var body: some View {
        VStack(spacing: 20) {
            if authState.isAuthenticated {
                // Success state
                successView
            } else if authState.showingAuthSheet {
                // Show embedded auth
                authWebView
            } else {
                // Initial state - prompt to connect
                connectPromptView
            }
        }
        .padding()
        .onChange(of: authState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated {
                // Close the auth sheet if open
                authState.showingAuthSheet = false
            }
        }
    }

    private var connectPromptView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "link.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Connect to Last.fm")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Sign in to your Last.fm account to start scrobbling your music.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                startAuthentication()
            } label: {
                HStack {
                    Image(systemName: "person.badge.key")
                    Text("Connect Last.fm Account")
                }
                .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(authState.isAuthenticating)

            if authState.isAuthenticating {
                ProgressView("Preparing authentication...")
                    .font(.caption)
            }

            if let error = authState.authError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()

            Text("You'll be redirected to Last.fm to authorize the app.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var authWebView: some View {
        VStack(spacing: 0) {
            if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                if authState.isAuthenticating {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(1.2)

                        Text("Completing authentication...")
                            .font(.headline)

                        Text("Please wait while we verify your account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if #available(macOS 26, *) {
                        OnboardingWebAuthView(lastFmManager: desktopManager)
                            .environment(authState)
                    } else {
                        OnboardingWebAuthViewLegacy(lastFmManager: desktopManager)
                            .environment(authState)
                    }
                }
            }
        }
    }

    private var successView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Connected!")
                    .font(.title2)
                    .fontWeight(.semibold)

                if let username = UserDefaults.standard.string(forKey: "lastFmUsername"),
                   !username.isEmpty {
                    Text("Signed in as \(username)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Your Last.fm account is now connected. Click Continue to proceed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func startAuthentication() {
        guard let manager = scrobbler.lastFmManager as? LastFmDesktopManager else { return }

        if manager.currentAuthToken.isEmpty {
            manager.startAuth()
        } else {
            authState.showingAuthSheet = true
        }
    }
}

// MARK: - Embedded Web Auth Views for Onboarding

@available(macOS 26, *)
struct OnboardingWebAuthView: View {
    var lastFmManager: LastFmDesktopManager
    @Environment(AuthState.self) var authState
    @State private var webPage = WebPage()
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.7)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                Button("Reload") {
                    loadAuthPage()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // WebView
            WebView(webPage)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .onAppear {
                    loadAuthPage()
                }
                .onChange(of: webPage.isLoading) { _, newValue in
                    isLoading = newValue
                    if !newValue {
                        checkIfAuthorizationComplete()
                    }
                }

            // Footer
            HStack {
                Button("Cancel") {
                    authState.showingAuthSheet = false
                    lastFmManager.completeAuthorization(authorized: false)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("I've Authorized the App") {
                    completeAuthorization()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onDisappear {
            webPage.stopLoading()
        }
    }

    private func loadAuthPage() {
        guard !lastFmManager.currentAuthToken.isEmpty else {
            authState.authError = "No authentication token available"
            return
        }

        isLoading = true
        authState.authError = nil

        let authURL = "https://www.last.fm/api/auth/?api_key=\(lastFmManager.apiKey)&token=\(lastFmManager.currentAuthToken)&cb=scrobble://auth"

        if let url = URL(string: authURL) {
            let request = URLRequest(url: url)
            let _ = webPage.load(request)
        }
    }

    private func checkIfAuthorizationComplete() {
        Task {
            do {
                let urlScript = "window.location.href"
                if let currentURL = try await webPage.callJavaScript(urlScript) as? String {
                    if currentURL.contains("authorized") || currentURL.contains("/api/grantaccess") {
                        await MainActor.run {
                            completeAuthorization()
                        }
                    }
                }
            } catch {
                Log.error("Error checking URL: \(error)", category: .ui)
            }
        }
    }

    private func completeAuthorization() {
        authState.isAuthenticating = true
        lastFmManager.completeAuthorization(authorized: true)
    }
}

// Legacy version for macOS 15
struct OnboardingWebAuthViewLegacy: View {
    var lastFmManager: LastFmDesktopManager
    @Environment(AuthState.self) var authState
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 16) {
            Text("Connect to Last.fm")
                .font(.headline)

            if isLoading {
                ProgressView("Opening Last.fm...")
            }

            Text("A browser window will open for you to authorize the app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Button("Cancel") {
                    authState.showingAuthSheet = false
                    lastFmManager.completeAuthorization(authorized: false)
                }
                .buttonStyle(.bordered)

                Button("I've Authorized") {
                    authState.isAuthenticating = true
                    lastFmManager.completeAuthorization(authorized: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            openAuthInBrowser()
        }
    }

    private func openAuthInBrowser() {
        guard !lastFmManager.currentAuthToken.isEmpty else {
            authState.authError = "No authentication token available"
            return
        }

        let authURL = "https://www.last.fm/api/auth/?api_key=\(lastFmManager.apiKey)&token=\(lastFmManager.currentAuthToken)&cb=scrobble://auth"

        if let url = URL(string: authURL) {
            NSWorkspace.shared.open(url)
            isLoading = false
        }
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

    OnboardingAuthView()
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .environment(authState)
        .frame(width: 500, height: 450)
}
