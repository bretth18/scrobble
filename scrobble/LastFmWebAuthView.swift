//
//  LastFmWebAuthView.swift
//  scrobble
//
//  Created by Assistant on 2/4/25.
//

import SwiftUI
import WebKit

struct LastFmWebAuthView: View {
    @ObservedObject var lastFmManager: LastFmDesktopManager
    @EnvironmentObject var authState: AuthState
    @State private var webPage = WebPage()
    @State private var isLoading = true
    
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
                .onChange(of: webPage.currentNavigationEvent) { _, newEvent in
                    handleNavigationChange(newEvent)
                }
            
            // Footer
            HStack(spacing: 16) {
                Button("Cancel") {
                    authState.isAuthenticating = false
                    lastFmManager.completeAuthorization(authorized: false)
                }
                
                Spacer()
                
                if !isLoading {
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
        
        let authURL = "http://www.last.fm/api/auth/?api_key=\(lastFmManager.apiKey)&token=\(lastFmManager.currentAuthToken)"
        
        if let url = URL(string: authURL) {
            let request = URLRequest(url: url)
            let _ = webPage.load(request)
        }
    }
    
    private func handleNavigationChange(_ event: WebPage.NavigationEvent?) {
        guard let event = event else { return }
        
        switch event.state {
        case .started:
            isLoading = true
            authState.authError = nil
            
        case .finished:
            isLoading = false
            checkIfAuthorizationComplete()
            
        case .failed:
            isLoading = false
            if let error = event.error {
                authState.authError = "Failed to load: \(error.localizedDescription)"
            }
            
        default:
            break
        }
    }
    
    private func checkIfAuthorizationComplete() {
        // Check if we're on a success page or if the URL indicates success
        guard let currentURL = webPage.currentNavigationEvent?.frameInfo.request.url?.absoluteString else {
            return
        }
        
        print("Current URL: \(currentURL)")
        
        // Check if we're on a page that indicates successful authorization
        // Last.fm typically shows a success page or redirects after successful auth
        if currentURL.contains("authorized") || 
           currentURL.contains("success") || 
           currentURL.contains("callback") ||
           isLastFmSuccessPage() {
            
            print("Authorization appears complete, attempting to get session...")
            authState.isAuthenticating = true
            lastFmManager.completeAuthorization(authorized: true)
        }
    }
    
    private func isLastFmSuccessPage() -> Bool {
        // We can check the page content to see if authorization was successful
        // This is a simplified approach - you might want to check for specific content
        Task {
            do {
                let script = """
                document.body.innerText.toLowerCase().includes('authorized') || 
                document.body.innerText.toLowerCase().includes('success') ||
                document.querySelector('.auth-success, .success, .authorized') !== null
                """
                
                let result = try await webPage.callJavaScript(script)
                if let isSuccess = result as? Bool, isSuccess {
                    DispatchQueue.main.async {
                        print("Detected successful authorization via page content")
                        self.authState.isAuthenticating = true
                        self.lastFmManager.completeAuthorization(authorized: true)
                    }
                }
            } catch {
                print("Error checking page content: \(error)")
            }
        }
        
        return false
    }
}

#Preview {
    LastFmWebAuthView(lastFmManager: LastFmDesktopManager(apiKey: "test", apiSecret: "test", username: "test"))
        .environmentObject(AuthState.shared)
}