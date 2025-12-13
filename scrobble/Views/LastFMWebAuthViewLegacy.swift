//
//  LastFMWebAuthViewLegacy.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//
//  Legacy WKWebView-based auth view for macOS 15 compatibility

import SwiftUI
import WebKit

struct LastFMWebAuthViewLegacy: View {
    var lastFmManager: LastFmDesktopManager
    @Environment(AuthState.self) var authState
    @State private var isLoading = true
    @State private var currentURL = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Last.fm Authentication")
                    .font(.headline)

                if isLoading {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                        Text("Loading authorization page...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            // WebView
            LegacyWebView(
                lastFmManager: lastFmManager,
                isLoading: $isLoading,
                currentURL: $currentURL,
                onAuthorizationComplete: {
                    completeAuthorization()
                }
            )

            // Footer
            HStack(spacing: 16) {
                Button("Cancel") {
                    authState.isAuthenticating = false
                    lastFmManager.completeAuthorization(authorized: false)
                }

                Spacer()

                if !isLoading {
                    Button("I've authorized the app") {
                        completeAuthorization()
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("Reload") {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("LegacyWebViewReload"),
                            object: nil
                        )
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 600, height: 500)
    }

    private func completeAuthorization() {
        Log.debug("Completing authorization...", category: .ui)
        authState.isAuthenticating = true
        lastFmManager.completeAuthorization(authorized: true)
    }
}

// MARK: - WKWebView NSViewRepresentable Wrapper

struct LegacyWebView: NSViewRepresentable {
    var lastFmManager: LastFmDesktopManager
    @Binding var isLoading: Bool
    @Binding var currentURL: String
    var onAuthorizationComplete: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        // Listen for reload notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.reload),
            name: NSNotification.Name("LegacyWebViewReload"),
            object: nil
        )

        // Load auth page
        loadAuthPage(webView: webView)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // No updates needed
    }

    private func loadAuthPage(webView: WKWebView) {
        guard !lastFmManager.currentAuthToken.isEmpty else {
            return
        }

        let authURL = "https://www.last.fm/api/auth/?api_key=\(lastFmManager.apiKey)&token=\(lastFmManager.currentAuthToken)&cb=scrobble://auth"

        if let url = URL(string: authURL) {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: LegacyWebView
        weak var webView: WKWebView?

        init(_ parent: LegacyWebView) {
            self.parent = parent
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func reload() {
            guard let webView = webView,
                  !parent.lastFmManager.currentAuthToken.isEmpty else { return }

            let authURL = "https://www.last.fm/api/auth/?api_key=\(parent.lastFmManager.apiKey)&token=\(parent.lastFmManager.currentAuthToken)&cb=scrobble://auth"

            if let url = URL(string: authURL) {
                let request = URLRequest(url: url)
                webView.load(request)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.currentURL = webView.url?.absoluteString ?? ""
                self.checkIfAuthorizationComplete(webView: webView)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
            Log.error("WebView navigation failed: \(error)", category: .ui)
        }

        private func checkIfAuthorizationComplete(webView: WKWebView) {
            Log.debug("Checking if authorization is complete...", category: .ui)

            guard let currentURL = webView.url?.absoluteString else { return }

            Log.debug("Current URL: \(currentURL)", category: .ui)

            // Check URL patterns that might indicate success
            if currentURL.contains("authorized") ||
               currentURL.contains("success") ||
               currentURL.contains("callback") {
                Log.debug("Authorization appears complete based on URL", category: .ui)
                DispatchQueue.main.async {
                    self.parent.onAuthorizationComplete()
                }
                return
            }

            // Check page content for authorization indicators
            checkPageContentForSuccess(webView: webView)
        }

        private func checkPageContentForSuccess(webView: WKWebView) {
            let script = """
            (function() {
                const bodyText = document.body.innerText.toLowerCase();
                const hasSuccessText = bodyText.includes('authorized') ||
                                      bodyText.includes('success') ||
                                      bodyText.includes('application has been authorized') ||
                                      bodyText.includes('permission granted') ||
                                      bodyText.includes('you have successfully authorized');

                const hasSuccessElement = document.querySelector('.auth-success, .success, .authorized, .permission-granted, .successful') !== null;

                const hasLastFmSuccess = bodyText.includes('application authorized') ||
                                       bodyText.includes('app authorized') ||
                                       bodyText.includes('successfully granted');

                return hasSuccessText || hasSuccessElement || hasLastFmSuccess;
            })();
            """

            webView.evaluateJavaScript(script) { [weak self] result, error in
                if let error = error {
                    Log.error("Error checking page content: \(error)", category: .ui)
                    return
                }

                if let isSuccess = result as? Bool, isSuccess {
                    Log.debug("Detected successful authorization via page content", category: .ui)
                    DispatchQueue.main.async {
                        self?.parent.onAuthorizationComplete()
                    }
                } else {
                    Log.debug("No success indicators found yet", category: .ui)
                }
            }
        }
    }
}

#Preview {
    let authState = AuthState()
    let manager = LastFmDesktopManager(apiKey: "test", apiSecret: "test", username: "test", authState: authState)
    return LastFMWebAuthViewLegacy(lastFmManager: manager)
        .environment(authState)
}
