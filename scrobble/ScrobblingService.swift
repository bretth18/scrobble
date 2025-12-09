//
//  ScrobblingService.swift
//  scrobble
//
//  Created by Assistant on 1/25/25.
//

import Foundation
import Combine

/// Protocol that all scrobbling services must implement
protocol ScrobblingService {
    /// Unique identifier for this service
    var serviceId: String { get }
    
    /// Display name for this service
    var serviceName: String { get }
    
    /// Whether this service is currently authenticated and ready to scrobble
    var isAuthenticated: Bool { get }
    
    /// Stream that emits authentication status changes
    var authStatus: AsyncStream<Bool> { get }
    
    /// Scrobble a track that has been played
    func scrobble(artist: String, track: String, album: String) async throws -> Bool
    
    /// Update now playing status
    func updateNowPlaying(artist: String, track: String, album: String) async throws -> Bool
    
    /// Start authentication process if needed
    func authenticate() async throws -> Bool
    
    /// Sign out and clear authentication
    func signOut()
}

/// Adapter to make existing LastFmManagerType conform to ScrobblingService
class LastFmServiceAdapter: ScrobblingService {
    private let lastFmManager: LastFmManagerType
    
    var serviceId: String { "lastfm" }
    var serviceName: String { "Last.fm" }
    
    var isAuthenticated: Bool {
        if let desktopManager = lastFmManager as? LastFmDesktopManager {
            return desktopManager.authStatus == .authenticated
        }
        return false
    }
    
    
    
    var authStatus: AsyncStream<Bool> {
        AsyncStream { continuation in
            guard let desktopManager = lastFmManager as? LastFmDesktopManager else {
                continuation.yield(false)
                continuation.finish()
                return
            }

            let monitoringTask = Task {
                // Initial value
                continuation.yield(desktopManager.authStatus == .authenticated)

                // Subscribe to updates via AsyncSequence
                for await status in desktopManager.authStatusSubject.values {
                    let isAuth = (status == .authenticated)
                    continuation.yield(isAuth)
                }
            }

            continuation.onTermination = { _ in
                monitoringTask.cancel()
            }
        }
    }
    
    init(lastFmManager: LastFmManagerType) {
        self.lastFmManager = lastFmManager
    }
    
    func scrobble(artist: String, track: String, album: String) async throws -> Bool {
        Log.debug("Last.fm: Scrobbling \(artist) - \(track)", category: .scrobble)
        
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = lastFmManager.scrobble(artist: artist, track: track, album: album)
                .sink(receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break // Wait for value
                    case .failure(let error):
                        continuation.resume(throwing: error)
                        cancellable = nil
                    }
                }, receiveValue: { success in
                    continuation.resume(returning: success)
                    cancellable = nil
                })
        }
    }
    
    func updateNowPlaying(artist: String, track: String, album: String) async throws -> Bool {
        Log.debug("Last.fm: Updating now playing \(artist) - \(track)", category: .scrobble)
        
        return try await withCheckedThrowingContinuation { continuation in
             var cancellable: AnyCancellable?
             cancellable = lastFmManager.updateNowPlaying(artist: artist, track: track, album: album)
                 .sink(receiveCompletion: { completion in
                     switch completion {
                     case .finished:
                         break
                     case .failure(let error):
                         continuation.resume(throwing: error)
                         cancellable = nil
                     }
                 }, receiveValue: { success in
                     continuation.resume(returning: success)
                     cancellable = nil
                 })
         }
    }
    
    func authenticate() async throws -> Bool {
        if let desktopManager = lastFmManager as? LastFmDesktopManager {
            desktopManager.startAuth()

            for await status in desktopManager.authStatusSubject.values {
                if status == .authenticated { return true }
                if case .failed = status { return false }
            }
            return false
        }

        throw ScrobblerError.authenticationFailed
    }
    
    func signOut() {
        if let desktopManager = lastFmManager as? LastFmDesktopManager {
            desktopManager.logout()
        }
    }
}

extension ScrobblerError {
    static let authenticationFailed = ScrobblerError.apiError("Authentication failed")
}
