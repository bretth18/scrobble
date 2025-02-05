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

class LastFmDesktopManager: ObservableObject, LastFmManagerType {
    private let apiKey: String
    private let apiSecret: String
    private let username: String
    private let password: String  // Kept for API compatibility but not used
    private var sessionKey: String?
    private var isAuthenticated = false
    private var authenticationSubject = PassthroughSubject<Void, Error>()
    
    private var cancellables = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.lastfm.api", qos: .background)

    // Keep same init signature for compatibility
    init(apiKey: String, apiSecret: String, username: String, password: String) {
        self.apiKey = apiKey
        self.apiSecret = apiSecret
        self.username = username
        self.password = password  // Stored but not used
        
        // Try to load existing session key
        if let savedSessionKey = UserDefaults.standard.string(forKey: "lastfm_session_key") {
            self.sessionKey = savedSessionKey
            self.isAuthenticated = true
            validateSavedSession()
        } else {
            authenticate()
        }
    }
    
    private func validateSavedSession() {
        guard let sessionKey = self.sessionKey else { return }
        
        // Test the session with a simple API call
        let parameters: [String: String] = [
            "method": "user.getInfo",
            "user": username,
            "api_key": apiKey,
            "sk": sessionKey
        ]
        
        makeRequest(parameters: parameters)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        print("Saved session invalid, starting new authentication")
                        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
                        self?.sessionKey = nil
                        self?.isAuthenticated = false
                        self?.authenticate()
                    }
                },
                receiveValue: { _ in
                    print("Saved session validated successfully")
                }
            )
            .store(in: &cancellables)
    }
    
    private func authenticate() {
        print("Starting desktop authentication flow for user: \(username)")
        getToken()
            .flatMap { [weak self] token -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
                }
                
                return self.handleUserAuthorization(token: token)
            }
            .flatMap { [weak self] token -> AnyPublisher<String, Error> in
                guard let self = self else {
                    return Fail(error: ScrobblerError.noSessionKey).eraseToAnyPublisher()
                }
                return self.getSession(token: token)
            }
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("Authentication error: \(error)")
                        self?.authenticationSubject.send(completion: .failure(error))
                    }
                },
                receiveValue: { [weak self] sessionKey in
                    self?.sessionKey = sessionKey
                    self?.isAuthenticated = true
                    UserDefaults.standard.set(sessionKey, forKey: "lastfm_session_key")
                    self?.authenticationSubject.send(())
                    print("Authentication completed successfully")
                }
            )
            .store(in: &cancellables)
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
    
    // Observers for SwiftUI state
    @Published var showingAuthSheet = false
    @Published var authToken: String = ""
    private var authPromise: ((Result<String, Error>) -> Void)?

    private func handleUserAuthorization(token: String) -> AnyPublisher<String, Error> {
        return Future { [weak self] promise in
            guard let self = self else { return }
            
            self.authPromise = promise
            self.authToken = token
            
            // Open the authorization URL in default browser
            let authURL = "http://www.last.fm/api/auth/?api_key=\(self.apiKey)&token=\(token)"
            if let url = URL(string: authURL) {
                NSWorkspace.shared.open(url)
            }
            
            DispatchQueue.main.async {
                self.showingAuthSheet = true
            }
        }.eraseToAnyPublisher()
    }
    
    // Call this method from your SwiftUI view when user completes auth
    func completeAuthorization(authorized: Bool) {
        showingAuthSheet = false
        if authorized {
            authPromise?(.success(authToken))
        } else {
            authPromise?(.failure(ScrobblerError.authorizationCancelled))
        }
        authPromise = nil
    }
    
    private func getSession(token: String) -> AnyPublisher<String, Error> {
        let parameters: [String: Any] = [
            "method": "auth.getSession",
            "api_key": apiKey,
            "token": token
        ]
        
        let signature = createSignature(parameters: parameters)
        var allParameters = parameters
        allParameters["api_sig"] = signature
        allParameters["format"] = "json"
        
        return makeRequest(parameters: allParameters)
            .decode(type: SessionResponse.self, decoder: JSONDecoder())
            .map { $0.session.key }
            .eraseToAnyPublisher()
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


// Add this to your ScrobblerError enum
extension ScrobblerError {
    static let authorizationCancelled = ScrobblerError.apiError("Authorization was cancelled by user")
}
