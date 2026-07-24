//
//  LastFmCatalogClient.swift
//  scrobble
//
//  Unauthenticated Last.fm catalog lookups — api key only, deliberately
//  independent of the auth/session stack so metadata validation works
//  signed-out and never touches auth state.
//

import Foundation

struct LastFmCatalogClient: Sendable {

    struct TrackMatch: Sendable {
        let artist: String
        let title: String
        let album: String?
        let listeners: Int
    }

    let apiKey: String

    /// Returns nil when Last.fm definitively doesn't know the track
    /// (API error 6); throws on transport or service failures so callers
    /// can distinguish "no" from "couldn't ask".
    func lookupTrack(artist: String, title: String) async throws -> TrackMatch? {
        var components = URLComponents(string: "https://ws.audioscrobbler.com/2.0/")!
        components.queryItems = [
            URLQueryItem(name: "method", value: "track.getInfo"),
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "artist", value: artist),
            URLQueryItem(name: "track", value: title),
            URLQueryItem(name: "autocorrect", value: "1"),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else {
            throw ScrobblerError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ScrobblerError.apiError("Invalid response type")
        }

        // Last.fm returns API errors as JSON bodies (with varying HTTP codes).
        if let apiError = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            if apiError.error == 6 { return nil } // "Track not found"
            throw ScrobblerError.apiError("Last.fm error \(apiError.error): \(apiError.message)")
        }

        guard httpResponse.statusCode == 200 else {
            throw ScrobblerError.apiError("HTTP \(httpResponse.statusCode)")
        }

        let payload = try JSONDecoder().decode(Response.self, from: data)
        return TrackMatch(
            artist: payload.track.artist.name,
            title: payload.track.name,
            album: payload.track.album?.title,
            listeners: Int(payload.track.listeners ?? "") ?? 0
        )
    }

    private struct Response: Codable {
        let track: Track

        struct Track: Codable {
            let name: String
            let listeners: String?
            let artist: Artist
            let album: Album?

            struct Artist: Codable { let name: String }
            struct Album: Codable { let title: String }
        }
    }
}
