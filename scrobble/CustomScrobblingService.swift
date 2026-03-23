//
//  CustomScrobblingService.swift
//  scrobble
//
//  Created by Brett Henderson on 1/25/25.
//

import Foundation



enum CustomScrobbleRequestBody {

}

class CustomScrobblingService: ScrobblingService {
    let serviceId = "custom"
    let serviceName = "Custom Scrobbler"

    private let oauthManager: BlueskyOAuthManager
    private let baseURL = "https://clientserver-production-be44.up.railway.app"

    @MainActor
    var isAuthenticated: Bool {
        oauthManager.isAuthenticated
    }

    var authStatus: AsyncStream<Bool> {
        let (stream, continuation) = AsyncStream.makeStream(of: Bool.self)

        // Use a polling approach with reasonable interval instead of busy-wait observation
        // Auth state changes are infrequent (user-initiated), so 1 second polling is fine
        let monitoringTask = Task { @MainActor in
            var previousState = oauthManager.isAuthenticated
            continuation.yield(previousState)

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }

                let newState = oauthManager.isAuthenticated
                if newState != previousState {
                    continuation.yield(newState)
                    previousState = newState
                }
            }
            continuation.finish()
        }

        continuation.onTermination = { _ in
            monitoringTask.cancel()
        }

        return stream
    }

    init(blueskyHandle: String) {
        self.oauthManager = BlueskyOAuthManager(blueskyHandle: blueskyHandle)
    }

    func authenticate() async throws -> Bool {
        await oauthManager.startAuthentication()

        for await isAuth in authStatus {
            if isAuth { return true }
            if let error = oauthManager.authError {
                throw ScrobblerError.apiError(error)
            }
            if !oauthManager.isAuthenticating && !isAuth {
                return false
            }
        }
        return false
    }

    func signOut() {
        // Sign out on main actor
        Task { @MainActor in
            oauthManager.signOut()
        }
    }

    func scrobble(artist: String, track: String, album: String) async throws -> Bool {
        guard isAuthenticated else {
            Log.debug("Custom scrobbler: Not authenticated", category: .scrobble)
            throw ScrobblerError.authenticationRequired
        }

        Log.debug("Custom scrobbler: Scrobbling \(artist) - \(track)", category: .scrobble)
        return try await makeScrobbleRequest(
            method: "track.scrobble",
            artist: artist,
            track: track,
            album: album,
            timestamp: Int(Date().timeIntervalSince1970)
        )
    }

    func updateNowPlaying(artist: String, track: String, album: String) async throws -> Bool {
        guard isAuthenticated else {
            Log.error("Custom scrobbler: Not authenticated for now playing update", category: .scrobble)
            throw ScrobblerError.authenticationRequired
        }

        Log.debug("Custom scrobbler: Updating now playing \(artist) - \(track)", category: .scrobble)
        return try await makeScrobbleRequest(
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
    ) async throws -> Bool {

        Log.debug("Custom scrobbler: Making \(method) request to \(baseURL)", category: .scrobble)

        guard let url = URL(string: "\(baseURL)/api/\(method)") else {
            Log.error("Custom scrobbler: Invalid URL \(baseURL)/api/\(method)", category: .scrobble)
            throw ScrobblerError.invalidURL
        }

        // Create authenticated request
        var request = oauthManager.createAuthenticatedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create scrobble object matching the expected API format
        var scrobbleObject: [String: Any] = [
            "artist": artist,
            "track": track,
            "album": album
        ]

        if let timestamp = timestamp {
            scrobbleObject["timestamp"] = String(timestamp)
        }

        let requestBody: Any = (method == "track.scrobble") ? [scrobbleObject] : scrobbleObject

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            Log.error("Custom scrobbler: Failed to serialize request body: \(error)", category: .scrobble)
            throw error
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
             Log.error("Custom scrobbler: Invalid response type", category: .scrobble)
             throw ScrobblerError.apiError("Invalid response type")
        }

        Log.debug("Custom scrobbler: Received HTTP \(httpResponse.statusCode)", category: .scrobble)

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
             Log.error("Custom scrobbler: HTTP error \(httpResponse.statusCode): \(responseString)", category: .scrobble)
             throw ScrobblerError.apiError("HTTP error \(httpResponse.statusCode): \(responseString)")
        }

        return true
    }
}
