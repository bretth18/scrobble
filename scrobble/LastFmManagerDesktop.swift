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
    private let queue = DispatchQueue(label: "com.lastfm.api", qos: .background)
    
    private var authPromise: ((Result<String, Error>) -> Void)?
    var authToken: String = ""
    var currentAuthToken: String = ""
    
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
        
        checkSavedAuth()
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
                        print("Saved session invalid, starting new authentication")
                        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
                        self?.sessionKey = nil
                        self?.isAuthenticated = false
                        self?.authStatus = .needsAuth
                    }
                },
                receiveValue: { _ in
                    print("Saved session validated successfully")
                    self.authStatus = .authenticated
                }
            )
            .store(in: &cancellables)
    }
    
    func startAuth() {
        print("Starting desktop authentication flow")
        authState.startAuth()
        
        getToken()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.handleAuthFailure("Failed to get authentication token: \(error.localizedDescription)")
                    }
                },
                receiveValue: { [weak self] token in
                    guard let self = self else { return }
                    
                    self.currentAuthToken = token
                    print("Got token: \(token)")
                    
                    // Show the auth sheet with WebKit view
                    DispatchQueue.main.async {
                        self.authState.showingAuthSheet = true
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleAuthFailure(_ message: String) {
        DispatchQueue.main.async {
            self.authState.isAuthenticating = false
            self.authState.showingAuthSheet = false
            self.authState.authError = message
            self.authStatus = .failed(message)
        }
    }
    
    private func completeAuthWithSessionKey(_ sessionKey: String) {
        self.sessionKey = sessionKey
        UserDefaults.standard.set(sessionKey, forKey: "lastfm_session_key")
        self.isAuthenticated = true
        
        DispatchQueue.main.async {
            self.authState.isAuthenticating = false
            self.authState.showingAuthSheet = false
            self.authState.authError = nil
            self.authStatus = .authenticated
            self.authenticationSubject.send(())
        }
    }
    
    func completeAuthorization(authorized: Bool) {
        print("Complete authorization called with authorized: \(authorized)")
        if authorized {
            // User clicked Continue, so now get the session using the stored token
            authState.isAuthenticating = true
            authState.showingAuthSheet = false
            
            getSession(token: currentAuthToken)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        DispatchQueue.main.async {
                            self?.authState.isAuthenticating = false
                        }
                        if case .failure(let error) = completion {
                            self?.handleAuthFailure("Authentication failed: \(error.localizedDescription)")
                        }
                    },
                    receiveValue: { [weak self] sessionKey in
                        self?.completeAuthWithSessionKey(sessionKey)
                    }
                )
                .store(in: &cancellables)
        } else {
            handleAuthFailure("Authorization was cancelled")
        }
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
                    print("Failed to reopen auth URL: \(error)")
                } else {
                    print("Reopened auth URL in new browser window: \(url)")
                }
            }
        }
    }
    
    private func waitForUserAuthorization(token: String) -> AnyPublisher<String, Error> {
        print("Waiting for user authorization with token: \(token)")
        return Future { [weak self] promise in
            self?.authPromise = promise
        }.eraseToAnyPublisher()
    }
    
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
        print("Requesting session with token: \(token)")
        // Add a small delay to allow Last.fm to process the authorization
        return Future { promise in
            // Wait 3 seconds before requesting the session
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                print("Making session request after delay...")
                let parameters: [String: Any] = [
                    "method": "auth.getSession",
                    "api_key": self.apiKey,
                    "token": token
                ]
                
                let signature = self.createSignature(parameters: parameters)
                var allParameters = parameters
                allParameters["api_sig"] = signature
                allParameters["format"] = "json"
                
                print("Session request parameters: \(allParameters)")
                
                self.makeRequest(parameters: allParameters)
                    .handleEvents(receiveOutput: { data in
                        // Log the raw response for debugging
                        if let jsonString = String(data: data, encoding: .utf8) {
                            print("Raw session response: \(jsonString)")
                        }
                    })
                    .tryMap { data -> SessionResponse in
                        // Try to decode as an error response first
                        if let errorResponse = try? JSONDecoder().decode(LastFmErrorResponse.self, from: data) {
                            print("Last.fm API returned error \(errorResponse.error): \(errorResponse.message)")
                            throw ScrobblerError.apiError("Last.fm error \(errorResponse.error): \(errorResponse.message)")
                        }
                        
                        // Try to decode as a successful session response
                        return try JSONDecoder().decode(SessionResponse.self, from: data)
                    }
                    .map { response in
                        print("Session response received: \(response.session)")
                        return response.session.key
                    }
                    .sink(
                        receiveCompletion: { completion in
                            switch completion {
                            case .failure(let error):
                                print("Session request failed with error: \(error)")
                                if let urlError = error as? URLError {
                                    print("URLError details: \(urlError.localizedDescription)")
                                }
                                promise(.failure(error))
                            case .finished:
                                print("Session request completed successfully")
                            }
                        },
                        receiveValue: { sessionKey in
                            print("Session key received: \(sessionKey)")
                            promise(.success(sessionKey))
                        }
                    )
                    .store(in: &self.cancellables)
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
        
        print("Getting friends with parameters: \(parameters)")
        
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
            .subscribe(on: queue)
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
        sessionKey = nil
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
        DispatchQueue.main.async {
            self.authState.signOut()
            self.authStatus = .needsAuth
        }
    }
}
