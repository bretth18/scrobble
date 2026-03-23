//
//  LastFmManagerDesktop.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import SwiftUI
import Combine
import CryptoKit

struct Secrets {
    static var lastFmApiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "LastFmApiKey") as? String ?? ""
    }

    static var lastFmApiSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "LastFmApiSecret") as? String ?? ""
    }
}

// MARK: - Testable Crypto Utilities

func md5(_ string: String) -> String {
    guard let data = string.data(using: .utf8) else { return "" }
    return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
}

func createLastFmSignature(parameters: [String: Any], secret: String) -> String {
    let sortedKeys = parameters.keys.sorted()
    let concatenatedString = sortedKeys.reduce("") { result, key in
        let value = parameters[key]!
        return result + key + "\(value)"
    }
    let signatureString = concatenatedString + secret
    return md5(signatureString)
}

@Observable
@MainActor
class LastFmDesktopManager: LastFmManagerType {
    let apiKey: String  // Made public for WebKit auth view
    private let apiSecret: String
    private let initialUsername: String
    private let password: String  // Kept for API compatibility but not used

    /// Resolves the effective username: prefers Keychain, falls back to UserDefaults backup, then init value
    private var effectiveUsername: String {
        KeychainHelper.load(key: "lastfm_username")
            ?? UserDefaults.standard.string(forKey: "lastfm_username_backup")
            ?? initialUsername
    }
    private var sessionKey: String?
    private var isAuthenticated = false
    private var authenticationSubject = PassthroughSubject<Void, Error>()

    // Combine publisher for compatibility with ScrobblingService
    let authStatusSubject = CurrentValueSubject<AuthStatus, Never>(.unknown)

    private(set) var authStatus: AuthStatus = .unknown {
        didSet {
            authStatusSubject.send(authStatus)
        }
    }
    var isAuthenticating = false

    var authState: AuthState
    private var cancellables = Set<AnyCancellable>()

    private var authPromise: ((Result<String, Error>) -> Void)?
    var authToken: String = ""
    var currentAuthToken: String = "" {
        didSet {
            // Persist token during auth flow for recovery
            if !currentAuthToken.isEmpty {
                UserDefaults.standard.set(currentAuthToken, forKey: "lastfm_pending_auth_token")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastfm_pending_auth_token")
            }
        }
    }

    // Authorization lock to prevent duplicate completion calls
    private var isCompletingAuthorization = false

    // Auth timeout task
    private var authTimeoutTask: Task<Void, Never>?

    // Retry configuration
    private let maxRetryAttempts = 3
    private let baseRetryDelay: Duration = .seconds(2)
    
    enum AuthStatus: Equatable {
        case unknown
        case needsAuth
        case authenticated
        case failed(String)
    }

    // Keep same init signature for compatibility
    init(apiKey: String, apiSecret: String, username: String, password: String = "", authState: AuthState) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.initialUsername = username
        self.password = password
        self.authState = authState

        // Recover pending auth token if app restarted mid-auth
        if let pendingToken = UserDefaults.standard.string(forKey: "lastfm_pending_auth_token") {
            self.currentAuthToken = pendingToken
            Log.debug("Recovered pending auth token from previous session", category: .auth)
        }

        checkSavedAuth()
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("LastFmAuthSuccess"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                if let token = notification.userInfo?["token"] as? String {
                    Log.debug("Received auth success notification with token: \(token)", category: .scrobble)

                    // Verify tokens match if we have one expected
                    if !self.currentAuthToken.isEmpty, self.currentAuthToken != token {
                        Log.debug("Warning: Received callback token \(token) differs from expected \(self.currentAuthToken)", category: .scrobble)
                    }

                    // If we received a token, we can assume it's the right one or update ours
                    if self.currentAuthToken.isEmpty {
                        self.currentAuthToken = token
                    }

                    self.completeAuthorization(authorized: true)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("LastFmAuthFailure"))
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let error = notification.userInfo?["error"] as? String {
                    self?.handleAuthFailure("Last.fm reported error: \(error)")
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkSavedAuth() {
        // Try Keychain first, fall back to UserDefaults.
        // UserDefaults fallback is kept because Keychain ACLs can break
        // between Xcode dev builds when the app is re-signed.
        if let savedSessionKey = KeychainHelper.load(key: "lastfm_session_key") {
            self.sessionKey = savedSessionKey
            validateSavedSession()
        } else if let fallbackSessionKey = UserDefaults.standard.string(forKey: "lastfm_session_key") {
            Log.debug("Keychain miss, recovering session from UserDefaults", category: .auth)
            self.sessionKey = fallbackSessionKey
            // Try to save back to Keychain for next time
            _ = KeychainHelper.save(key: "lastfm_session_key", value: fallbackSessionKey)
            if !initialUsername.isEmpty {
                _ = KeychainHelper.save(key: "lastfm_username", value: initialUsername)
            }
            validateSavedSession()
        } else {
            authStatus = .needsAuth
        }
    }
    
    private func validateSavedSession() {
        guard let sessionKey = self.sessionKey else {
            authStatus = .needsAuth
            return
        }

        // Use effective username (prefers Keychain, falls back to init value)
        let validationUser = effectiveUsername

        // Test the session with a simple API call
        var parameters: [String: String] = [
            "method": "user.getInfo",
            "api_key": apiKey,
            "sk": sessionKey
        ]
        if !validationUser.isEmpty {
            parameters["user"] = validationUser
        }

        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"

        Task {
            do {
                _ = try await makeRequestAsync(parameters: parameters)
                Log.debug("Saved session validated successfully", category: .auth)
                self.isAuthenticated = true
                self.authStatus = .authenticated
                self.authState.isAuthenticated = true
            } catch {
                // Only clear the session for explicit auth errors from Last.fm
                let isAuthError: Bool
                if let scrobblerError = error as? ScrobblerError,
                   case .apiError(let message) = scrobblerError {
                    isAuthError = message.contains("error 4:") || message.contains("error 9:") || message.contains("error 26:")
                } else {
                    isAuthError = false
                }

                if isAuthError {
                    Log.debug("Saved session invalid, clearing auth", category: .auth)
                    KeychainHelper.delete(key: "lastfm_session_key")
                    KeychainHelper.delete(key: "lastfm_username")
                    self.sessionKey = nil
                    self.isAuthenticated = false
                    self.authStatus = .needsAuth
                    self.authState.isAuthenticated = false
                } else {
                    Log.debug("Session validation failed (transient), keeping session: \(error.localizedDescription)", category: .auth)
                    self.isAuthenticated = true
                    self.authStatus = .authenticated
                    self.authState.isAuthenticated = true
                }
            }
        }
    }
    
    func startAuth() {
        Log.debug("Starting desktop authentication flow", category: .auth)

        // Reset authorization lock
        isCompletingAuthorization = false

        // Cancel any existing timeout
        authTimeoutTask?.cancel()

        authState.startAuth()

        Task {
            do {
                let token = try await getTokenAsync()
                self.currentAuthToken = token
                Log.debug("Got token: \(token)", category: .auth)

                // Show the auth sheet with WebKit view
                self.authState.showingAuthSheet = true

                // Start auth timeout (60 seconds)
                startAuthTimeout()
            } catch {
                handleAuthFailure("Failed to get authentication token: \(error.localizedDescription)")
            }
        }
    }

    private func startAuthTimeout() {
        authTimeoutTask?.cancel()
        authTimeoutTask = Task {
            do {
                try await Task.sleep(for: .seconds(60))
                // If we get here, auth timed out
                if !Task.isCancelled && authState.showingAuthSheet {
                    Log.debug("Authentication timed out after 60 seconds", category: .auth)
                    handleAuthFailure("Authentication timed out. Please try again.")
                }
            } catch {
                // Task was cancelled, which is expected on successful auth
            }
        }
    }

    private func cancelAuthTimeout() {
        authTimeoutTask?.cancel()
        authTimeoutTask = nil
    }
    
    private func handleAuthFailure(_ message: String) {
        cancelAuthTimeout()
        isCompletingAuthorization = false

        // Clear pending auth token
        currentAuthToken = ""

        authState.isAuthenticating = false
        authState.showingAuthSheet = false
        authState.authError = message
        authStatus = .failed(message)
    }

    private func completeAuthWithSessionKey(_ sessionKey: String, username: String? = nil) {
        cancelAuthTimeout()

        self.sessionKey = sessionKey
        _ = KeychainHelper.save(key: "lastfm_session_key", value: sessionKey)
        // Keep UserDefaults as fallback in case Keychain ACL breaks after re-signing
        UserDefaults.standard.set(sessionKey, forKey: "lastfm_session_key")
        if let username, !username.isEmpty {
            _ = KeychainHelper.save(key: "lastfm_username", value: username)
            UserDefaults.standard.set(username, forKey: "lastfm_username_backup")
        }
        self.isAuthenticated = true

        // Clear pending auth token (auth is complete)
        currentAuthToken = ""
        isCompletingAuthorization = false

        authState.isAuthenticating = false
        authState.showingAuthSheet = false
        authState.authError = nil
        authState.isAuthenticated = true
        authStatus = .authenticated
        authenticationSubject.send(())

        Log.debug("Authentication completed successfully", category: .auth)
    }
    
    func completeAuthorization(authorized: Bool) {
        Log.debug("Complete authorization called with authorized: \(authorized)", category: .auth)

        // Prevent duplicate authorization completions
        guard !isCompletingAuthorization else {
            Log.debug("Authorization already in progress, ignoring duplicate call", category: .auth)
            return
        }

        if authorized {
            isCompletingAuthorization = true

            // User clicked Continue, so now get the session using the stored token
            // Keep sheet open but switch to spinner view
            authState.isAuthenticating = true
            // authState.showingAuthSheet stays true to show spinner

            Task {
                do {
                    let result = try await getSessionWithRetry(token: currentAuthToken)
                    completeAuthWithSessionKey(result.key, username: result.username)
                } catch {
                    handleAuthFailure("Authentication failed: \(error.localizedDescription)")
                }
            }
        } else {
            handleAuthFailure("Authorization was cancelled")
        }
    }

    /// Gets session with exponential backoff retry
    private func getSessionWithRetry(token: String) async throws -> SessionResult {
        var lastError: Error?

        for attempt in 0..<maxRetryAttempts {
            do {
                // Calculate delay with exponential backoff (0s, 2s, 4s)
                if attempt > 0 {
                    let delay = baseRetryDelay * (1 << (attempt - 1))
                    Log.debug("Retry attempt \(attempt + 1)/\(maxRetryAttempts) after \(delay) delay", category: .auth)
                    try await Task.sleep(for: delay)
                }

                let result = try await getSessionAsync(token: token)
                return result
            } catch {
                lastError = error
                Log.debug("Session request attempt \(attempt + 1) failed: \(error.localizedDescription)", category: .auth)

                // Check if this is a non-retryable error
                if let scrobblerError = error as? ScrobblerError {
                    switch scrobblerError {
                    case .apiError(let message):
                        // Error 4 = "Invalid authentication token" - non-retryable
                        // Error 14 = "This token has not been authorized" - retryable
                        // Error 15 = "This token has expired" - non-retryable
                        if message.contains("error 4:") || message.contains("error 15:") {
                            throw error
                        }
                    default:
                        break
                    }
                }
            }
        }

        throw lastError ?? ScrobblerError.apiError("Failed to get session after \(maxRetryAttempts) attempts")
    }
    
    func reopenAuthURL() {
        guard !currentAuthToken.isEmpty else {
            handleAuthFailure("No auth token available. Please restart the authentication process.")
            return
        }
        
        // Re-open the auth URL with the current token
        let callbackURL = "scrobble://auth-complete"
        if let url = URL(string: "http://www.last.fm/api/auth/?api_key=\(self.apiKey)&token=\(currentAuthToken)&cb=\(callbackURL)") {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            Task {
                do {
                    _ = try await NSWorkspace.shared.open(url, configuration: configuration)
                    Log.debug("Reopened auth URL in new browser window: \(url)", category: .auth)
                } catch {
                    Log.error("Failed to reopen auth URL: \(error)", category: .auth)
                }
            }
        }
    }
    
    private func waitForUserAuthorization(token: String) -> AnyPublisher<String, Error> {
        Log.debug("Waiting for user authorization with token: \(token)", category: .auth)
        return Future { [weak self] promise in
            self?.authPromise = promise
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Async/Await API Methods

    private func getTokenAsync() async throws -> String {
        let parameters: [String: Any] = [
            "method": "auth.getToken",
            "api_key": apiKey
        ]

        let signature = createSignature(parameters: parameters)
        var allParameters = parameters
        allParameters["api_sig"] = signature
        allParameters["format"] = "json"

        let data = try await makeRequestAsync(parameters: allParameters)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)
        return response.token
    }

    private struct SessionResult {
        let key: String
        let username: String
    }

    private func getSessionAsync(token: String) async throws -> SessionResult {
        Log.debug("Requesting session with token: \(token)", category: .auth)

        let parameters: [String: Any] = [
            "method": "auth.getSession",
            "api_key": self.apiKey,
            "token": token
        ]

        let signature = self.createSignature(parameters: parameters)
        var allParameters = parameters
        allParameters["api_sig"] = signature
        allParameters["format"] = "json"

        Log.debug("Session request parameters: \(allParameters)", category: .auth)

        let data = try await makeRequestAsync(parameters: allParameters)

        // Log the raw response for debugging
        if let jsonString = String(data: data, encoding: .utf8) {
            Log.debug("Raw session response: \(jsonString)", category: .auth)
        }

        // Try to decode as an error response first
        if let errorResponse = try? JSONDecoder().decode(LastFmErrorResponse.self, from: data) {
            Log.error("Last.fm API returned error \(errorResponse.error): \(errorResponse.message)", category: .auth)
            throw ScrobblerError.apiError("Last.fm error \(errorResponse.error): \(errorResponse.message)")
        }

        // Try to decode as a successful session response
        let response = try JSONDecoder().decode(SessionResponse.self, from: data)
        Log.debug("Session response received: \(response.session)", category: .auth)
        return SessionResult(key: response.session.key, username: response.session.name)
    }

    private func makeRequestAsync(parameters: [String: Any]) async throws -> Data {
        let baseURL = "https://ws.audioscrobbler.com/2.0/"
        var components = URLComponents(string: baseURL)!
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }

        guard let url = components.url else {
            throw ScrobblerError.invalidURL
        }

        var request = URLRequest(url: url)
        if parameters["method"] as? String == "track.scrobble" ||
           parameters["method"] as? String == "track.updateNowPlaying" {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        let (data, _) = try await URLSession.shared.data(for: request)

        // Check for API errors
        if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            throw ScrobblerError.apiError(errorResponse.message)
        }

        return data
    }

    // MARK: - Public API

    func scrobble(artist: String, track: String, album: String) async throws -> Bool {
        guard let sessionKey = self.sessionKey else {
            throw ScrobblerError.noSessionKey
        }

        let timestamp = Int(Date.now.timeIntervalSince1970)
        var parameters: [String: String] = [
            "method": "track.scrobble",
            "artist": artist,
            "track": track,
            "album": album,
            "timestamp": String(timestamp),
            "api_key": apiKey,
            "sk": sessionKey
        ]

        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"

        let data = try await makeRequestAsync(parameters: parameters)
        let response = try JSONDecoder().decode(ScrobbleResponse.self, from: data)
        return response.scrobbles.attr.accepted == 1
    }

    func updateNowPlaying(artist: String, track: String, album: String) async throws -> Bool {
        guard let sessionKey = self.sessionKey else {
            throw ScrobblerError.noSessionKey
        }

        var parameters: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": artist,
            "track": track,
            "album": album,
            "api_key": apiKey,
            "sk": sessionKey
        ]

        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"

        _ = try await makeRequestAsync(parameters: parameters)
        return true
    }

    func getFriends(page: Int = 1, limit: Int = 50) async throws -> [Friend] {
        guard let sessionKey = self.sessionKey else {
            throw ScrobblerError.noSessionKey
        }

        var parameters: [String: String] = [
            "method": "user.getFriends",
            "user": effectiveUsername,
            "api_key": apiKey,
            "sk": sessionKey,
            "page": String(page),
            "limit": String(limit),
        ]

        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"

        Log.debug("Getting friends with parameters: \(parameters)", category: .general)

        let data = try await makeRequestAsync(parameters: parameters)
        let response = try JSONDecoder().decode(FriendsResponse.self, from: data)
        return response.friends.user
    }

    func getRecentTracks(for username: String, page: Int = 1, limit: Int = 50) async throws -> [RecentTracksResponse.RecentTracks.Track] {
        var parameters: [String: String] = [
            "method": "user.getRecentTracks",
            "user": username,
            "api_key": apiKey,
            "page": String(page),
            "limit": String(limit),
        ]

        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"

        let data = try await makeRequestAsync(parameters: parameters)
        let response = try JSONDecoder().decode(RecentTracksResponse.self, from: data)
        return response.recenttracks.track
    }
    
    // MARK: - Helper Methods
    
    private func createSignature(parameters: [String: Any]) -> String {
        createLastFmSignature(parameters: parameters, secret: apiSecret)
    }
}

// MARK: - Response Types
private struct TokenResponse: Codable {
    let token: String
}

private struct SessionResponse: Codable {
    let session: Session
    struct Session: Codable {
        let name: String
        let key: String
        let subscriber: Int
    }
}

private struct LastFmErrorResponse: Codable {
    let error: Int
    let message: String
}
extension LastFmDesktopManager {
    func logout() {
        // Cancel any pending auth operations
        cancelAuthTimeout()
        isCompletingAuthorization = false

        // Clear all auth state
        sessionKey = nil
        currentAuthToken = ""  // This also clears UserDefaults pending token
        KeychainHelper.delete(key: "lastfm_session_key")
        KeychainHelper.delete(key: "lastfm_username")
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
        UserDefaults.standard.removeObject(forKey: "lastfm_username_backup")

        authState.signOut()
        authStatus = .needsAuth

        Log.debug("Logged out and cleared all auth state", category: .auth)
    }
}
