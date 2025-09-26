//
//  BlueskyOAuthManager.swift
//  scrobble
//
//  Created by Assistant on 1/25/25.
//

import Foundation
import Combine
import AppKit
import WebKit

class BlueskyOAuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isAuthenticating = false
    @Published var authError: String?
    
    private let blueskyHandle: String
    private let baseURL = "https://clientserver-production-be44.up.railway.app"
    private var authWindow: NSWindow?
    private var webView: WKWebView?
    private var cancellables = Set<AnyCancellable>()
    
    // Session management
    private var sessionCookies: [HTTPCookie] = []
    
    init(blueskyHandle: String) {
        self.blueskyHandle = blueskyHandle
        checkExistingAuth()
    }
    
    private func checkExistingAuth() {
        // Check if we have stored cookies for this handle
        if let cookieData = UserDefaults.standard.data(forKey: "bluesky_auth_cookies_\(blueskyHandle)") {
            do {
                let cookies = try JSONDecoder().decode([CookieData].self, from: cookieData)
                sessionCookies = cookies.compactMap { $0.toCookie() }
                
                // Test if the session is still valid
                testAuthenticationStatus()
            } catch {
                print("Failed to decode stored cookies: \(error)")
                clearStoredAuth()
            }
        }
    }
    
    private func testAuthenticationStatus() {
        // Make a test request to see if our session is still valid
        var request = URLRequest(url: URL(string: "\(baseURL)/api/auth/status")!)
        
        // Add cookies to request
        for cookie in sessionCookies {
            if let cookieHeader = HTTPCookie.requestHeaderFields(with: [cookie])["Cookie"] {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
        }
        
        URLSession.shared.dataTaskPublisher(for: request)
            .map(\.response)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.isAuthenticated = false
                        self?.clearStoredAuth()
                    }
                },
                receiveValue: { [weak self] response in
                    if let httpResponse = response as? HTTPURLResponse {
                        self?.isAuthenticated = (200...299).contains(httpResponse.statusCode)
                        if !self?.isAuthenticated ?? false {
                            self?.clearStoredAuth()
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    func startAuthentication() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        authError = nil
        
        // Create the OAuth login URL
        let oauthURL = "\(baseURL)/oauth/login?handle=\(blueskyHandle)"
        
        guard let url = URL(string: oauthURL) else {
            authError = "Invalid OAuth URL"
            isAuthenticating = false
            return
        }
        
        // Create a new window with WebKit view
        createAuthWindow(with: url)
    }
    
    private func createAuthWindow(with url: URL) {
        let windowRect = NSRect(x: 0, y: 0, width: 800, height: 600)
        
        authWindow = NSWindow(
            contentRect: windowRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        authWindow?.title = "Bluesky Authentication"
        authWindow?.center()
        authWindow?.isReleasedWhenClosed = false
        
        // Create WebKit configuration
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.nonPersistent() // Start fresh
        
        // Create WebKit view
        webView = WKWebView(frame: windowRect, configuration: config)
        webView?.navigationDelegate = self
        
        authWindow?.contentView = webView
        authWindow?.makeKeyAndOrderFront(nil)
        
        // Load the OAuth URL
        let request = URLRequest(url: url)
        webView?.load(request)
    }
    
    private func completeAuthentication(success: Bool, error: String? = nil) {
        DispatchQueue.main.async {
            self.isAuthenticating = false
            
            if success {
                self.isAuthenticated = true
                self.authError = nil
                print("Bluesky OAuth authentication successful")
            } else {
                self.isAuthenticated = false
                self.authError = error ?? "Authentication failed"
                print("Bluesky OAuth authentication failed: \(error ?? "unknown error")")
            }
            
            // Close auth window
            self.authWindow?.close()
            self.authWindow = nil
            self.webView = nil
        }
    }
    
    private func extractAndStoreCookies() {
        guard let webView = webView else { return }
        
        // Get all cookies from the WebView
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            // Filter for cookies from our domain
            let relevantCookies = cookies.filter { cookie in
                cookie.domain.contains("railway.app") && cookie.name.lowercased().contains("jwt")
            }
            
            if !relevantCookies.isEmpty {
                self.sessionCookies = relevantCookies
                self.storeCookies(relevantCookies)
                self.completeAuthentication(success: true)
            } else {
                // Look for any session-related cookies
                let sessionCookies = cookies.filter { cookie in
                    cookie.domain.contains("railway.app") && 
                    (cookie.name.lowercased().contains("session") || 
                     cookie.name.lowercased().contains("auth") ||
                     cookie.name.lowercased().contains("token"))
                }
                
                if !sessionCookies.isEmpty {
                    self.sessionCookies = sessionCookies
                    self.storeCookies(sessionCookies)
                    self.completeAuthentication(success: true)
                } else {
                    self.completeAuthentication(success: false, error: "No authentication cookies found")
                }
            }
        }
    }
    
    private func storeCookies(_ cookies: [HTTPCookie]) {
        let cookieData = cookies.map { CookieData(from: $0) }
        do {
            let data = try JSONEncoder().encode(cookieData)
            UserDefaults.standard.set(data, forKey: "bluesky_auth_cookies_\(blueskyHandle)")
        } catch {
            print("Failed to store cookies: \(error)")
        }
    }
    
    private func clearStoredAuth() {
        UserDefaults.standard.removeObject(forKey: "bluesky_auth_cookies_\(blueskyHandle)")
        sessionCookies.removeAll()
        isAuthenticated = false
    }
    
    func signOut() {
        clearStoredAuth()
        
        // Also clear WebKit data store if needed
        let dataStore = WKWebsiteDataStore.default()
        dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), 
                           modifiedSince: Date(timeIntervalSince1970: 0)) {
            print("WebKit data cleared for sign out")
        }
    }
    
    // Create authenticated URLRequest with cookies
    func createAuthenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        // Add cookies to request
        if !sessionCookies.isEmpty {
            let cookieHeader = HTTPCookie.requestHeaderFields(with: sessionCookies)["Cookie"] ?? ""
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        
        return request
    }
}

// MARK: - WKNavigationDelegate
extension BlueskyOAuthManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Check if we're on a success page or if authentication is complete
        if let url = webView.url?.absoluteString {
            print("Navigation finished: \(url)")
            
            // Check if we're back at the base domain after OAuth
            if url.contains("clientserver-production-be44.up.railway.app") && 
               !url.contains("oauth/login") &&
               !url.contains("bsky.app") {
                
                // Likely completed OAuth flow, extract cookies
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.extractAndStoreCookies()
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView navigation failed: \(error)")
        completeAuthentication(success: false, error: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("WebView provisional navigation failed: \(error)")
        completeAuthentication(success: false, error: error.localizedDescription)
    }
}

// MARK: - Cookie serialization helper
private struct CookieData: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let isSecure: Bool
    let isHttpOnly: Bool
    let expiresDate: Date?
    
    init(from cookie: HTTPCookie) {
        self.name = cookie.name
        self.value = cookie.value
        self.domain = cookie.domain
        self.path = cookie.path
        self.isSecure = cookie.isSecure
        self.isHttpOnly = cookie.isHTTPOnly
        self.expiresDate = cookie.expiresDate
    }
    
    func toCookie() -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path
        ]
        
        if isSecure {
            properties[.secure] = true
        }
        
        if isHttpOnly {
            properties[.init("HttpOnly")] = true
        }
        
        if let expiresDate = expiresDate {
            properties[.expires] = expiresDate
        }
        
        return HTTPCookie(properties: properties)
    }
}