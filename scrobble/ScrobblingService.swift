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
    
    /// Publisher that emits authentication status changes
    var authenticationPublisher: AnyPublisher<Bool, Never> { get }
    
    /// Scrobble a track that has been played
    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error>
    
    /// Update now playing status
    func updateNowPlaying(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error>
    
    /// Start authentication process if needed
    func authenticate() -> AnyPublisher<Bool, Error>
    
    /// Sign out and clear authentication
    func signOut()
}

/// Adapter to make existing LastFmManagerType conform to ScrobblingService
class LastFmServiceAdapter: ScrobblingService {
    private let lastFmManager: LastFmManagerType
    private let authStatusSubject = CurrentValueSubject<Bool, Never>(false)
    
    var serviceId: String { "lastfm" }
    var serviceName: String { "Last.fm" }
    
    var isAuthenticated: Bool {
        if let desktopManager = lastFmManager as? LastFmDesktopManager {
            return desktopManager.authStatus == .authenticated
        }
        return false
    }
    
    var authenticationPublisher: AnyPublisher<Bool, Never> {
        authStatusSubject.eraseToAnyPublisher()
    }
    
    init(lastFmManager: LastFmManagerType) {
        self.lastFmManager = lastFmManager
        
        // Monitor auth status changes if it's a desktop manager
        if let desktopManager = lastFmManager as? LastFmDesktopManager {
            desktopManager.$authStatus
                .map { status in
                    switch status {
                    case .authenticated:
                        return true
                    default:
                        return false
                    }
                }
                .subscribe(authStatusSubject)
        }
    }
    
    func scrobble(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        lastFmManager.scrobble(artist: artist, track: track, album: album)
    }
    
    func updateNowPlaying(artist: String, track: String, album: String) -> AnyPublisher<Bool, Error> {
        lastFmManager.updateNowPlaying(artist: artist, track: track, album: album)
    }
    
    func authenticate() -> AnyPublisher<Bool, Error> {
        if let desktopManager = lastFmManager as? LastFmDesktopManager {
            desktopManager.startAuth()
            return desktopManager.$authStatus
                .compactMap { status in
                    switch status {
                    case .authenticated:
                        return true
                    case .failed:
                        return false
                    default:
                        return nil
                    }
                }
                .first()
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        return Fail(error: ScrobblerError.authenticationFailed).eraseToAnyPublisher()
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