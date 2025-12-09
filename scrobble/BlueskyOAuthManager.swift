//
//  BlueskyOAuthManager.swift
//  scrobble
//
//  Created by Assistant on 1/25/25.
//

import Foundation
import AppKit
import WebKit
import Observation


@Observable
class BlueskyOAuthManager: NSObject {
    @MainActor var isAuthenticated = false
    @MainActor var isAuthenticating = false
    @MainActor var authError: String?

    private let blueskyHandle: String
    private let baseURL = "https://clientserver-production-be44.up.railway.app"
    private var authWindow: NSWindow?
    private var webView: WKWebView?
    
    // Session management
    private var sessionCookies: [HTTPCookie] = []
    
    init(blueskyHandle: String) {
        self.blueskyHandle = blueskyHandle
        super.init()
        checkExistingAuth()
    }
    
    private func checkExistingAuth() {
        // Check if we have stored cookies for this handle
        if let cookieData = UserDefaults.standard.data(forKey: "bluesky_auth_cookies_\(blueskyHandle)") {
            do {
                let cookies = try JSONDecoder().decode([CookieData].self, from: cookieData)
                sessionCookies = cookies.compactMap { $0.toCookie() }

                Log.debug("Found \(sessionCookies.count) stored cookies for \(blueskyHandle)", category: .auth)

                // For now, assume stored cookies are valid
                // TODO: Implement proper session validation once you have a test endpoint
                if !sessionCookies.isEmpty {
                    Log.debug("Assuming stored auth is valid", category: .auth)
                    Task { @MainActor in
                        self.isAuthenticated = true
                    }
                } else {
                    Log.error("No valid cookies found", category: .auth)
                    Task { @MainActor in
                        await self.clearStoredAuth()
                    }
                }

                // Uncomment this when you have a proper auth test endpoint:
                // testAuthenticationStatus()
            } catch {
                Log.error("Failed to decode stored cookies: \(error)", category: .auth)
                Task { @MainActor in
                    await self.clearStoredAuth()
                }
            }
        } else {
            Log.debug("No stored cookies found for \(blueskyHandle)", category: .auth)
        }
    }
    
    private func testAuthenticationStatus() {
        Log.debug("Testing stored authentication status...", category: .auth)

        // Make a test request to see if our session is still valid
        // Try using a simple endpoint that should work with authentication
        guard let testURL = URL(string: "\(baseURL)/api/test") else {
            Log.error("Invalid test URL", category: .auth)
            Task { @MainActor in
                await self.clearStoredAuth()
            }
            return
        }

        var request = URLRequest(url: testURL)

        // Add cookies to request
        let cookieHeader = HTTPCookie.requestHeaderFields(with: sessionCookies)["Cookie"] ?? ""
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")

        Log.debug("Testing auth with cookies: \(sessionCookies.map { $0.name })", category: .auth)

        Task { @MainActor in
            do {
                let (_, response) = try await URLSession.shared.data(for: request)

                if let httpResponse = response as? HTTPURLResponse {
                    let isAuth = (200...299).contains(httpResponse.statusCode)
                    Log.debug("Auth test response: \(httpResponse.statusCode) - authenticated: \(isAuth)", category: .auth)
                    self.isAuthenticated = isAuth
                    if !isAuth && httpResponse.statusCode != 404 {
                        // Only clear auth if it's actually an auth failure, not a missing endpoint
                        await self.clearStoredAuth()
                    } else if httpResponse.statusCode == 404 {
                        // If the test endpoint doesn't exist, assume auth is valid if we have cookies
                        Log.debug("Test endpoint not found, assuming auth is valid", category: .auth)
                        self.isAuthenticated = !self.sessionCookies.isEmpty
                    }
                }
            } catch {
                Log.error("Auth test failed: \(error.localizedDescription)", category: .auth)
                // Don't immediately clear auth - the endpoint might not exist
                // Instead, assume auth is valid if we have cookies
                if !self.sessionCookies.isEmpty {
                    Log.debug("Assuming auth is valid since we have stored cookies", category: .auth)
                    self.isAuthenticated = true
                } else {
                    await self.clearStoredAuth()
                }
            }
        }
    }
    
    @MainActor
    func startAuthentication() async {
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
        Task { @MainActor in
            self.isAuthenticating = false
            
            if success {
                self.isAuthenticated = true
                self.authError = nil
                Log.debug("Bluesky OAuth authentication successful", category: .auth)
            } else {
                self.isAuthenticated = false
                self.authError = error ?? "Authentication failed"
                Log.error("Bluesky OAuth authentication failed: \(error ?? "unknown error")", category: .auth)
            }
            
            // Close auth window
            self.authWindow?.close()
            self.authWindow = nil
            self.webView = nil
        }
    }
    
    private func extractAndStoreCookies() {
        guard let webView = webView else { return }
        
        Log.debug("Extracting cookies from WebView...", category: .auth)
        
        // Get all cookies from the WebView
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self = self else { return }
            
            Log.debug("Total cookies found: \(cookies.count)", category: .auth)
            for cookie in cookies {
                Log.debug("Cookie: \(cookie.name) = \(cookie.value.prefix(20))... (domain: \(cookie.domain), path: \(cookie.path))", category: .auth)
            }
            
            // Filter for cookies from our Railway domain
            let railwayCookies = cookies.filter { cookie in
                cookie.domain.contains("railway.app") || cookie.domain.contains("clientserver-production-be44")
            }
            
            Log.debug("Railway domain cookies found: \(railwayCookies.count)", category: .auth)
            
            if !railwayCookies.isEmpty {
                // Look specifically for the 'auth' cookie first
                let authCookie = railwayCookies.first { cookie in
                    cookie.name.lowercased() == "auth"
                }
                
                if let authCookie = authCookie {
                    Log.debug("Found 'auth' cookie: \(authCookie.name)", category: .auth)
                    self.sessionCookies = [authCookie]
                    self.storeCookies([authCookie])
                    self.completeAuthentication(success: true)
                    return
                }
                
                // Fallback: look for any auth/session related cookies
                let authCookies = railwayCookies.filter { cookie in
                    let name = cookie.name.lowercased()
                    return name.contains("auth") ||
                           name.contains("session") || 
                           name.contains("jwt") ||
                           name.contains("token") ||
                           name.contains("access") ||
                           name.contains("bearer")
                }
                
                if !authCookies.isEmpty {
                    Log.debug("Found auth-related cookies: \(authCookies.map { $0.name })", category: .auth)
                    self.sessionCookies = authCookies
                    self.storeCookies(authCookies)
                    self.completeAuthentication(success: true)
                    return
                }
                
                // If we have Railway cookies but none match our expected patterns,
                // let's try using all of them
                Log.debug("Using all Railway cookies as potential auth cookies: \(railwayCookies.map { $0.name })", category: .auth)
                self.sessionCookies = railwayCookies
                self.storeCookies(railwayCookies)
                self.completeAuthentication(success: true)
            } else {
                Log.error("No Railway domain cookies found", category: .auth)
                self.completeAuthentication(success: false, error: "No authentication cookies found")
            }
        }
    }
    
    private func storeCookies(_ cookies: [HTTPCookie]) {
        let cookieData = cookies.map { CookieData(from: $0) }
        do {
            let data = try JSONEncoder().encode(cookieData)
            UserDefaults.standard.set(data, forKey: "bluesky_auth_cookies_\(blueskyHandle)")
        } catch {
            Log.error("Failed to store cookies: \(error)", category: .auth)
        }
    }
    
    @MainActor
    private func clearStoredAuth() {
        UserDefaults.standard.removeObject(forKey: "bluesky_auth_cookies_\(blueskyHandle)")
        sessionCookies.removeAll()
        isAuthenticated = false
    }
    
    @MainActor
    func signOut() {
        // Log out via server endpoint using our auth cookies, then clear local state
        let logoutURLString = "\(baseURL)/oauth/logout"
        guard let logoutURL = URL(string: logoutURLString) else {
            Log.error("Invalid logout URL", category: .auth)
            clearStoredAuth()
            return
        }

        // Build authenticated request with cookies
        var request = createAuthenticatedRequest(url: logoutURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        Log.debug("Logging out via \(logoutURLString) with cookies: \(sessionCookies.map { $0.name })", category: .auth)

        Task {
            do {
                let (_, response) = try await URLSession.shared.data(for: request)

                if let http = response as? HTTPURLResponse {
                    Log.debug("Logout response status: \(http.statusCode)", category: .auth)
                    if http.statusCode == 405 {
                        // Some servers use GET for logout, retry with GET
                        var getRequest = self.createAuthenticatedRequest(url: logoutURL)
                        getRequest.httpMethod = "GET"
                        let (_, resp2) = try await URLSession.shared.data(for: getRequest)
                        if let http2 = resp2 as? HTTPURLResponse {
                            Log.debug("Logout (GET) response status: \(http2.statusCode)", category: .auth)
                        }
                    }
                }
            } catch {
                Log.error("Logout request failed: \(error.localizedDescription)", category: .auth)
            }

            // Clear local state (already on MainActor from signOut)
            self.clearStoredAuth()
            // Also clear WebKit default data store if needed
            let dataStore = WKWebsiteDataStore.default()
            dataStore.removeData(
                ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
                modifiedSince: Date(timeIntervalSince1970: 0)
            ) {
                Log.debug("WebKit data cleared for sign out", category: .auth)
            }
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
            Log.debug("Navigation finished: \(url)", category: .auth)
            
            // Check if we're back at the base domain after OAuth (but not on the initial login page)
            if url.contains("clientserver-production-be44.up.railway.app") && 
               !url.contains("oauth/login") &&
               !url.contains("bsky.social") {
                
                Log.debug("Detected successful OAuth redirect to Railway app - extracting cookies", category: .auth)
                // Likely completed OAuth flow, extract cookies
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.extractAndStoreCookies()
                }
            } else if url.contains("bsky.social") {
                Log.debug("On Bluesky OAuth page - waiting for user to complete authentication", category: .auth)
                // We're on the Bluesky OAuth page, user needs to enter credentials
                // Don't close the window, just wait
            } else if url.contains("oauth/login") {
                Log.debug("On initial OAuth login page", category: .auth)
                // Initial page, this is expected
            } else {
                Log.debug("Navigation to unexpected URL: \(url)", category: .auth)
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Log.error("WebView navigation failed: \(error)", category: .auth)
        completeAuthentication(success: false, error: error.localizedDescription)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Log.error("WebView provisional navigation failed: \(error)", category: .auth)
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
