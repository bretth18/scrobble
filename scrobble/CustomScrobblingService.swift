//
//  CustomScrobblingService.swift
//  scrobble
//
//  Created by Assistant on 1/25/25.
//

import Foundation
import Combine

class CustomScrobblingService: ScrobblingService {
    let serviceId = "custom"
    let serviceName = "Custom Scrobbler"
    
    private let oauthManager: BlueskyOAuthManager
    private let baseURL = "https://clientserver-production-be44.up.railway.app"
    private var cancellables = Set<AnyCancellable>()
    
    var isAuthenticated: Bool {
        oauthManager.isAuthenticated
    }
    
    var authenticationPublisher: AnyPublisher<Bool, Never> {
        oauthManager.$isAuthenticated.eraseToAnyPublisher()
    }
    
    init(blueskyHandle: String) {
        self.oauthManager = BlueskyOAuthManager(blueskyHandle: blueskyHandle)
    }
    
    func authenticate() -> AnyPublisher<Bool, Error> {
        return Future { [weak self] promise in
            guard let self = self else {
                promise(.failure(ScrobblerError.apiError("Service deallocated")))
                return
            }
            
            // Start authentication
            self.oauthManager.startAuthentication()
            
            // Monitor authentication result
            self.oauthManager.$isAuthenticated
                .combineLatest(self.oauthManager.$isAuthenticating)
                .filter { _, isAuthenticating in !isAuthenticating } // Wait for authentication to complete
                .first()
                .map { isAuthenticated, _ in isAuthenticated }
                .sink { isAuthenticated in
                    if isAuthenticated {
                        promise(.success(true))
                    } else {
                        let errorMessage = self.oauthManager.authError ?? "Authentication failed"
                        promise(.failure(ScrobblerError.apiError(errorMessage)))
                    }
                }
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    func signOut() {
        oauthManager.signOut()
    }
    
    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        guard isAuthenticated else {
            return Fail(error: ScrobblerError.notAuthenticated).eraseToAnyPublisher()
        }
        
        return makeScrobbleRequest(
            method: "track.scrobble",
            artist: artist,
            track: track,
            album: album,
            timestamp: Int(Date().timeIntervalSince1970)
        )
    }
    
    func updateNowPlaying(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        guard isAuthenticated else {
            return Fail(error: ScrobblerError.notAuthenticated).eraseToAnyPublisher()
        }
        
        return makeScrobbleRequest(
            method: "track.updateNowPlaying",
            artist: artist,
            track: track,
            album: album
        )
    }
    
    private func makeScrobbleRequest(
        method: String,
        artist: String,
        track: String,
        album: String,
        timestamp: Int? = nil
    ) -> AnyPublisher<Bool, Error> {
        
        guard let url = URL(string: "\(baseURL)/api/\(method)") else {
            return Fail(error: ScrobblerError.invalidURL).eraseToAnyPublisher()
        }
        
        // Create authenticated request
        var request = oauthManager.createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create request body matching Last.fm API format
        var requestBody: [String: Any] = [
            "artist": artist,
            "track": track,
            "album": album
        ]
        
        if let timestamp = timestamp {
            requestBody["timestamp"] = timestamp
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ScrobblerError.invalidResponse
                }
                
                // Check for successful status codes
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to parse error message from response
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String {
                        throw ScrobblerError.apiError(errorMessage)
                    } else {
                        throw ScrobblerError.httpError(httpResponse.statusCode)
                    }
                }
                
                // For successful responses, try to parse the result
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Log successful response for debugging
                    print("Custom scrobbler response: \(jsonResponse)")
                    
                    // You can check for specific success indicators here if your API provides them
                    // For now, we'll consider any 2xx response as success
                    return true
                } else {
                    // Even if we can't parse JSON, a 2xx status code indicates success
                    return true
                }
            }
            .eraseToAnyPublisher()
    }
}

extension ScrobblerError {
    static let notAuthenticated = ScrobblerError.apiError("Not authenticated")
    static let invalidResponse = ScrobblerError.apiError("Invalid response")
    
    static func httpError(_ statusCode: Int) -> ScrobblerError {
        return ScrobblerError.apiError("HTTP error \(statusCode)")
    }
}