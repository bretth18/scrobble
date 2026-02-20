//
//  LastFMWebAuthView.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI
import WebKit
import Observation

@available(macOS 26, *)
struct LastFMWebAuthView: View {
    var lastFmManager: LastFmDesktopManager
    @Environment(AuthState.self) var authState
    @State private var webPage = WebPage()
    @State private var isLoading = true
    @State private var currentURL = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignTokens.spacingDefault) {
                Text("Last.fm Authentication")
                    .font(.headline)

                if isLoading {
                    HStack(spacing: DesignTokens.spacingDefault) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                        Text("Loading authorization page...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(.bar)

            // WebView
            WebView(webPage)
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
            HStack(spacing: DesignTokens.spacingLarge) {
                Button("Cancel", role: .cancel) {
                    authState.isAuthenticating = false
                    lastFmManager.completeAuthorization(authorized: false)
                }
                .buttonStyle(.glass)

                Spacer()

                if !isLoading {
                    Button("I've authorized the app") {
                        completeAuthorization()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.glassProminent)

                    Button("Reload") {
                        loadAuthPage()
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding()
            .background(.bar)
        }
        .frame(width: 600, height: 500)
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
            currentURL = authURL
        }
    }

    private func checkIfAuthorizationComplete() {
        Log.debug("Checking if authorization is complete...", category: .ui)

        Task {
            do {
                let urlScript = "window.location.href"
                if let currentURLResult = try await webPage.callJavaScript(urlScript) as? String {
                    currentURL = currentURLResult

                    if currentURL.contains("/api/auth") {
                        return
                    }

                    if currentURL.contains("authorized") ||
                       currentURL.contains("/api/grantaccess") {
                        await MainActor.run {
                            self.completeAuthorization()
                        }
                        return
                    }
                }

                await checkPageContentForSuccess()
            } catch {
                Log.error("Error checking URL: \(error)", category: .ui)
                await checkPageContentForSuccess()
            }
        }
    }

    private func checkPageContentForSuccess() async {
        if currentURL.contains("/api/auth") {
            return
        }

        do {
            let script = """
            function checkForSuccess() {
                const bodyText = document.body.innerText.toLowerCase();
                const hasExplicitSuccess =
                    bodyText.includes('application has been granted permission') ||
                    bodyText.includes('you can now close this window') ||
                    bodyText.includes('authorization successful') ||
                    bodyText.includes('you have successfully authorized');
                const hasSuccessElement = document.querySelector('.auth-success, .grant-success') !== null;
                return hasExplicitSuccess || hasSuccessElement;
            }
            return checkForSuccess();
            """

            let result = try await webPage.callJavaScript(script)
            if let isSuccess = result as? Bool, isSuccess {
                Log.debug("Detected successful authorization via page content", category: .ui)
                await MainActor.run {
                    self.completeAuthorization()
                }
            }
        } catch {
            Log.error("Error checking page content: \(error)", category: .ui)
        }
    }

    private func completeAuthorization() {
        authState.isAuthenticating = true
        lastFmManager.completeAuthorization(authorized: true)
    }
}

@available(macOS 26, *)
#Preview {
    let authState = AuthState()
    let manager = LastFmDesktopManager(apiKey: "test", apiSecret: "test", username: "test", authState: authState)
    return LastFMWebAuthView(lastFmManager: manager)
        .environment(authState)
}
