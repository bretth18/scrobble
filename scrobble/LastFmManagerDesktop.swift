//
//  LastFmManagerDesktop.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import Combine
import CommonCrypto
import CryptoKit
import AppKit
import SwiftUI
import Observation

import SwiftUI
import Observation

struct Secrets {
    static var lastFmApiKey: String {
        return Bundle.main.object(forInfoDictionaryKey: "LastFmApiKey") as? String ?? ""
    }
    
    static var lastFmApiSecret: String {
        return Bundle.main.object(forInfoDictionaryKey: "LastFmApiSecret") as? String ?? ""
    }
}

@Observable
@MainActor
class LastFmDesktopManager: LastFmManagerType {
    let apiKey: String  // Made public for WebKit auth view
    private let apiSecret: String
    private let username: String
    private let password: String  // Kept for API compatibility but not used
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
    private let baseRetryDelay: UInt64 = 2_000_000_000 // 2 seconds in nanoseconds
    
    enum AuthStatus: Equatable {
        case unknown
        case needsAuth
        case authenticated
        case failed(String)  // Changed from Error to String since Error isn't Equatable
        
        static func == (lhs: AuthStatus, rhs: AuthStatus) -> Bool {
            switch (lhs, rhs) {
            case (.unknown, .unknown):
                return true
            case (.needsAuth, .needsAuth):
                return true
            case (.authenticated, .authenticated):
                return true
            case (.failed(let lhsError), .failed(let rhsError)):
                return lhsError == rhsError
            default:
                return false
            }
        }
    }

    // Keep same init signature for compatibility
    init(apiKey: String, apiSecret: String, username: String, password: String = "", authState: AuthState) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.username = username
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
        if let savedSessionKey = UserDefaults.standard.string(forKey: "lastfm_session_key") {
            self.sessionKey = savedSessionKey
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
        
        // Test the session with a simple API call
        let parameters: [String: String] = [
            "method": "user.getInfo",
            "user": username,
            "api_key": apiKey,
            "sk": sessionKey
        ]
        
        makeRequest(parameters: parameters)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        Log.debug("Saved session invalid, starting new authentication", category: .auth)
                        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
                        self?.sessionKey = nil
                        self?.isAuthenticated = false
                        self?.authStatus = .needsAuth
                    }
                },
                receiveValue: { _ in
                    Log.debug("Saved session validated successfully", category: .auth)
                    self.authStatus = .authenticated
                }
            )
            .store(in: &cancellables)
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
                try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds
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

    private func completeAuthWithSessionKey(_ sessionKey: String) {
        cancelAuthTimeout()

        self.sessionKey = sessionKey
        UserDefaults.standard.set(sessionKey, forKey: "lastfm_session_key")
        self.isAuthenticated = true

        // Clear pending auth token (auth is complete)
        currentAuthToken = ""
        isCompletingAuthorization = false

        authState.isAuthenticating = false
        authState.showingAuthSheet = false
        authState.authError = nil
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
                    let sessionKey = try await getSessionWithRetry(token: currentAuthToken)
                    completeAuthWithSessionKey(sessionKey)
                } catch {
                    handleAuthFailure("Authentication failed: \(error.localizedDescription)")
                }
            }
        } else {
            handleAuthFailure("Authorization was cancelled")
        }
    }

    /// Gets session with exponential backoff retry
    private func getSessionWithRetry(token: String) async throws -> String {
        var lastError: Error?

        for attempt in 0..<maxRetryAttempts {
            do {
                // Calculate delay with exponential backoff (0s, 2s, 4s)
                if attempt > 0 {
                    let delay = baseRetryDelay * UInt64(1 << (attempt - 1))
                    Log.debug("Retry attempt \(attempt + 1)/\(maxRetryAttempts) after \(delay / 1_000_000_000)s delay", category: .auth)
                    try await Task.sleep(nanoseconds: delay)
                }

                let sessionKey = try await getSessionAsync(token: token)
                return sessionKey
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
            NSWorkspace.shared.open(url, configuration: configuration) { app, error in
                if let error = error {
                    Log.error("Failed to reopen auth URL: \(error)", category: .auth)
                } else {
                    Log.debug("Reopened auth URL in new browser window: \(url)", category: .auth)
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

    private func getSessionAsync(token: String) async throws -> String {
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
        return response.session.key
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

    // MARK: - Legacy Combine API Methods (kept for compatibility)

    private func getToken() -> AnyPublisher<String, Error> {
        let parameters: [String: Any] = [
            "method": "auth.getToken",
            "api_key": apiKey
        ]

        let signature = createSignature(parameters: parameters)
        var allParameters = parameters
        allParameters["api_sig"] = signature
        allParameters["format"] = "json"

        return makeRequest(parameters: allParameters)
            .decode(type: TokenResponse.self, decoder: JSONDecoder())
            .map { $0.token }
            .eraseToAnyPublisher()
    }

    private func getSession(token: String) -> AnyPublisher<String, Error> {
        Log.debug("Requesting session with token: \(token)", category: .auth)
        // Small delay to allow Last.fm to process the authorization
        return Future { promise in
            Task {
                do {
                    // Wait 3 seconds before requesting the session (legacy behavior)
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    Log.debug("Making session request after delay...", category: .auth)

                    let sessionKey = try await self.getSessionAsync(token: token)
                    promise(.success(sessionKey))
                } catch {
                    Log.error("Session request failed with error: \(error)", category: .auth)
                    promise(.failure(error))
                }
            }
        }.eraseToAnyPublisher()
    }
    
    // MARK: - Public API (matching original LastFmManager)
    
    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        guard let sessionKey = self.sessionKey else {
            return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
        }

        let timestamp = Int(Date().timeIntervalSince1970)
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
        
        return makeRequest(parameters: parameters)
            .decode(type: ScrobbleResponse.self, decoder: JSONDecoder())
            .map { $0.scrobbles.attr.accepted == 1 }
            .eraseToAnyPublisher()
    }
    
    func updateNowPlaying(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        guard let sessionKey = self.sessionKey else {
            return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
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
        
        return makeRequest(parameters: parameters)
            .map { _ in true }
            .eraseToAnyPublisher()
    }
    
    func getFriends(page: Int = 1, limit: Int = 50) -> AnyPublisher<[Friend], Error> {
        guard let sessionKey = self.sessionKey else {
            return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
        }

        var parameters: [String: String] = [
            "method": "user.getFriends",
            "user": username,
            "api_key": apiKey,
            "sk": sessionKey,
            "page": String(page),
            "limit": String(limit),
        ]
        
        let signature = createSignature(parameters: parameters)
        parameters["api_sig"] = signature
        parameters["format"] = "json"
        
        Log.debug("Getting friends with parameters: \(parameters)", category: .general)
        
        return makeRequest(parameters: parameters)
            .decode(type: FriendsResponse.self, decoder: JSONDecoder())
            .map { $0.friends.user }
            .eraseToAnyPublisher()
    }
    
    func getRecentTracks(for username: String, page: Int = 1, limit: Int = 50) -> AnyPublisher<[RecentTracksResponse.RecentTracks.Track], Error> {
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
        
        return makeRequest(parameters: parameters)
            .decode(type: RecentTracksResponse.self, decoder: JSONDecoder())
            .map { $0.recenttracks.track }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Helper Methods
    
    private func makeRequest(parameters: [String: Any]) -> AnyPublisher<Data, Error> {
        let baseURL = "https://ws.audioscrobbler.com/2.0/"
        var components = URLComponents(string: baseURL)!
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        
        guard let url = components.url else {
            return Fail(error: ScrobblerError.invalidURL).eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        if parameters["method"] as? String == "track.scrobble" ||
           parameters["method"] as? String == "track.updateNowPlaying" {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map(\.data)
            .tryMap { data in
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw ScrobblerError.apiError(errorResponse.message)
                }
                return data
            }
            .eraseToAnyPublisher()
    }
    
    private func createSignature(parameters: [String: Any]) -> String {
        let sortedKeys = parameters.keys.sorted()
        let concatenatedString = sortedKeys.reduce("") { result, key in
            let value = parameters[key]!
            return result + key + "\(value)"
        }
        let signatureString = concatenatedString + apiSecret
        return md5(string: signatureString)
    }
    
    private func md5(string: String) -> String {
        guard let data = string.data(using: .utf8) else { return "" }
        return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined()
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

extension ScrobblerError {
    static let authorizationCancelled = ScrobblerError.apiError("Authorization was cancelled by user")
}

extension LastFmDesktopManager {
    func logout() {
        // Cancel any pending auth operations
        cancelAuthTimeout()
        isCompletingAuthorization = false

        // Clear all auth state
        sessionKey = nil
        currentAuthToken = ""  // This also clears UserDefaults pending token
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")

        authState.signOut()
        authStatus = .needsAuth

        Log.debug("Logged out and cleared all auth state", category: .auth)
    }
}
