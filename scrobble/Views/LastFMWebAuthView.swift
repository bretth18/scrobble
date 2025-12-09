//
//  LastFMWebAuthView.swift
//  scrobble
//
//  Created by Assistant on 2/4/25.
//

import SwiftUI
import WebKit
import Observation

struct LastFMWebAuthView: View {
    var lastFmManager: LastFmDesktopManager
    @Environment(AuthState.self) var authState
    @State private var webPage = WebPage()
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
            WebView(webPage)
                .onAppear {
                    loadAuthPage()
                }
                .onChange(of: webPage.isLoading) { _, newValue in
                    isLoading = newValue
                    if !newValue {
                        // Page finished loading, check for authorization completion
                        checkIfAuthorizationComplete()
                    }
                }
            
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
                        loadAuthPage()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
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
        print("Checking if authorization is complete...")
        
        // First check the current URL
        Task {
            do {
                // Get the current URL from the webview
                let urlScript = "window.location.href"
                if let currentURLResult = try await webPage.callJavaScript(urlScript) as? String {
                    currentURL = currentURLResult
                    print("Current URL: \(currentURL)")
                    
                    // Check URL patterns that might indicate success
                    if currentURL.contains("authorized") || 
                       currentURL.contains("success") || 
                       currentURL.contains("callback") {
                        
                        print("Authorization appears complete based on URL, attempting to get session...")
                        DispatchQueue.main.async {
                            self.completeAuthorization()
                        }
                        return
                    }
                }
                
                // Check page content for authorization indicators
                await checkPageContentForSuccess()
            } catch {
                print("Error checking URL: \(error)")
                await checkPageContentForSuccess()
            }
        }
    }
    
    private func checkPageContentForSuccess() async {
        do {
            // Look for success indicators in the page
            let script = """
            function checkForSuccess() {
                const bodyText = document.body.innerText.toLowerCase();
                const hasSuccessText = bodyText.includes('authorized') || 
                                      bodyText.includes('success') ||
                                      bodyText.includes('application has been authorized') ||
                                      bodyText.includes('permission granted') ||
                                      bodyText.includes('you have successfully authorized');
                
                const hasSuccessElement = document.querySelector('.auth-success, .success, .authorized, .permission-granted, .successful') !== null;
                
                // Look for specific Last.fm success patterns
                const hasLastFmSuccess = bodyText.includes('application authorized') ||
                                       bodyText.includes('app authorized') ||
                                       bodyText.includes('successfully granted');
                
                console.log('Body text contains:', bodyText.substring(0, 200));
                console.log('Success indicators:', {hasSuccessText, hasSuccessElement, hasLastFmSuccess});
                
                return hasSuccessText || hasSuccessElement || hasLastFmSuccess;
            }
            return checkForSuccess();
            """
            
            let result = try await webPage.callJavaScript(script)
            if let isSuccess = result as? Bool, isSuccess {
                print("Detected successful authorization via page content")
                DispatchQueue.main.async {
                    self.completeAuthorization()
                }
            } else {
                print("No success indicators found yet")
            }
        } catch {
            print("Error checking page content: \(error)")
        }
    }
    
    private func completeAuthorization() {
        print("Completing authorization...")
        authState.isAuthenticating = true
        lastFmManager.completeAuthorization(authorized: true)
    }
}

#Preview {
    let authState = AuthState()
    let manager = LastFmDesktopManager(apiKey: "test", apiSecret: "test", username: "test", authState: authState)
    return LastFMWebAuthView(lastFmManager: manager)
        .environment(authState)
}
