//
//  CustomScrobblingService.swift
//  scrobble
//
//  Created by Assistant on 1/25/25.
//

import Foundation
import Combine


enum CustomScrobbleRequestBody {
    
}

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
            
            // Monitor authentication result - listen for changes in isAuthenticating to false
            self.oauthManager.$isAuthenticating
                .filter { !$0 } // Wait for authentication to complete (isAuthenticating becomes false)
                .first()
                .delay(for: .milliseconds(100), scheduler: RunLoop.main) // Small delay to ensure state is settled
                .sink { _ in
                    // Check final authentication state
                    if self.oauthManager.isAuthenticated {
                        Log.debug("Custom scrobbling service authentication successful", category: .scrobble)
                        promise(.success(true))
                    } else {
                        let errorMessage = self.oauthManager.authError ?? "Authentication failed"
                        Log.error("Custom scrobbling service authentication failed: \(errorMessage)", category: .scrobble)
                        promise(.failure(ScrobblerError.apiError(errorMessage)))
                    }
                }
                .store(in: &self.cancellables)
        }
        .eraseToAnyPublisher()
    }
    
    func signOut() {
        oauthManager.signOut()
        // Note: The servicesLastUpdated will be triggered by the authenticationPublisher subscription
    }
    
    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        guard isAuthenticated else {
            Log.debug("Custom scrobbler: Not authenticated", category: .scrobble)
            return Fail(error: ScrobblerError.authenticationRequired).eraseToAnyPublisher()
        }
        
        Log.debug("Custom scrobbler: Scrobbling \(artist) - \(track)", category: .scrobble)
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
            Log.error("Custom scrobbler: Not authenticated for now playing update", category: .scrobble)
            return Fail(error: ScrobblerError.authenticationRequired).eraseToAnyPublisher()
        }
        
        Log.debug("Custom scrobbler: Updating now playing \(artist) - \(track)", category: .scrobble)
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
        
        Log.debug("Custom scrobbler: Making \(method) request to \(baseURL)", category: .scrobble)
        
        guard let url = URL(string: "\(baseURL)/api/\(method)") else {
            Log.error("❌ Custom scrobbler: Invalid URL \(baseURL)/api/\(method)", category: .scrobble)
            return Fail(error: ScrobblerError.invalidURL).eraseToAnyPublisher()
        }
        
        // Create authenticated request
        var request = oauthManager.createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Log the request headers for debugging
        Log.debug("🔧 Custom scrobbler: Request headers: \(request.allHTTPHeaderFields ?? [:])", category: .scrobble)
        
        // Create scrobble object matching the expected API format
        var scrobbleObject: [String: Any] = [
            "artist": artist,
            "track": track,
            "album": album
        ]
        
        if let timestamp = timestamp {
            // The API expects timestamp as a string
            scrobbleObject["timestamp"] = String(timestamp)
            Log.debug("Custom scrobbler: Adding timestamp \(timestamp) as string", category: .scrobble)
        }
        
        // The API expects an array of scrobble objects
        let requestBody: Any
        if method == "track.scrobble" {
            requestBody = [scrobbleObject]
        } else {
            requestBody = scrobbleObject
        }
        
        Log.debug("Custom scrobbler: Request body: \(requestBody)", category: .scrobble)
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Log.error("Custom scrobbler: Failed to serialize request body: \(error)", category: .scrobble)
            return Fail(error: error).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: request)
            .map { data, response in
                Log.debug("📡 Custom scrobbler: Raw response received", category: .scrobble)
                return (data, response)
            }
            .tryMap { data, response -> Bool in
                guard let httpResponse = response as? HTTPURLResponse else {
                    Log.error("❌ Custom scrobbler: Invalid response type", category: .scrobble)
                    throw ScrobblerError.apiError("Invalid response type")
                }
                
                Log.debug("📡 Custom scrobbler: Received HTTP \(httpResponse.statusCode)", category: .scrobble)
                Log.debug("📡 Custom scrobbler: Response headers: \(httpResponse.allHeaderFields)", category: .scrobble)
                
                // Always log the response body for debugging
                let responseString = String(data: data, encoding: .utf8) ?? "No response body"
                Log.debug("📡 Custom scrobbler: Response body: \(responseString)", category: .scrobble)
                
                // Check for successful status codes
                guard (200...299).contains(httpResponse.statusCode) else {
                    // Try to parse error message from response
                    if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorData["error"] as? String {
                        Log.error("❌ Custom scrobbler: API error: \(errorMessage)", category: .scrobble)
                        throw ScrobblerError.apiError(errorMessage)
                    } else {
                        Log.error("❌ Custom scrobbler: HTTP error \(httpResponse.statusCode)", category: .scrobble)
                        Log.error("❌ Custom scrobbler: Full response body: \(responseString)", category: .scrobble)
                        throw ScrobblerError.apiError("HTTP error \(httpResponse.statusCode): \(responseString)")
                    }
                }
                
                // For successful responses, try to parse the result
                if let jsonResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Log successful response for debugging
                    Log.debug("✅ Custom scrobbler: Success response: \(jsonResponse)", category: .scrobble)
                    return true
                } else {
                    // Even if we can't parse JSON, a 2xx status code indicates success
                    Log.debug("✅ Custom scrobbler: Success (non-JSON response): \(responseString)", category: .scrobble)
                    return true
                }
            }
            .eraseToAnyPublisher()
    }
}

