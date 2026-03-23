//
//  FriendsModel.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import Observation

@Observable
@MainActor
class FriendsModel {
    var friends: [Friend] = []
    var friendTracks: [String: [RecentTracksResponse.RecentTracks.Track]] = [:]
    var isLoading = false
    var errorMessage: String?

    var preferencesManager: PreferencesManager?

    private var lastFmManager: LastFmManagerType
    private var lastFetchedAt: Date?
    private var loadTask: Task<Void, Never>?
    private static let cacheTTL: TimeInterval = 60

    init(lastFmManager: LastFmManagerType) {
        self.lastFmManager = lastFmManager
    }

    /// Update the manager reference without triggering a fetch.
    func setLastFmManager(_ manager: LastFmManagerType) {
        self.lastFmManager = manager
    }

    /// Update the manager and force a fresh fetch.
    func updateLastFmManager(_ manager: LastFmManagerType) {
        self.lastFmManager = manager
        loadFriends()
    }

    /// Called by pull-to-refresh and manual refresh button — always fetches.
    func refreshData() {
        loadFriends()
    }

    /// Called by onAppear — skips fetch if cache is fresh.
    func loadIfNeeded() {
        if let lastFetchedAt, Date.now.timeIntervalSince(lastFetchedAt) < Self.cacheTTL, !friends.isEmpty {
            Log.debug("FriendsModel: Cache still fresh, skipping fetch", category: .general)
            return
        }
        loadFriends()
    }

    private func loadFriends() {
        loadTask?.cancel()
        Log.debug("FriendsModel: Loading friends...", category: .general)
        isLoading = true
        errorMessage = nil

        let limit = preferencesManager?.numberOfFriendsDisplayed ?? 10
        Log.debug("FriendsModel: Fetching \(limit) friends", category: .general)

        loadTask = Task {
            do {
                let friends = try await lastFmManager.getFriends(page: 1, limit: limit)
                guard !Task.isCancelled else { return }
                Log.debug("FriendsModel: Loaded \(friends.count) friends", category: .general)
                self.friends = friends
                self.lastFetchedAt = Date.now
                self.isLoading = false
                await self.loadRecentTracksForFriends()
            } catch is CancellationError {
                // Normal — view disappeared or new load started
            } catch {
                guard !Task.isCancelled else { return }
                Log.error("FriendsModel: Error loading friends: \(error)", category: .general)
                self.isLoading = false
                if error.localizedDescription.contains("Missing parameter") {
                    self.errorMessage = "Configuration error: Missing username or API key."
                } else {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadRecentTracksForFriends() async {
        guard !friends.isEmpty else { return }
        Log.debug("FriendsModel: Loading recent tracks for \(friends.count) friends", category: .general)

        let limit = preferencesManager?.numberOfFriendsRecentTracksDisplayed ?? 3

        await withTaskGroup(of: (String, [RecentTracksResponse.RecentTracks.Track]?).self) { group in
            for friend in friends {
                let name = friend.name
                group.addTask {
                    do {
                        let tracks = try await self.lastFmManager.getRecentTracks(for: name, page: 1, limit: limit)
                        return (name, tracks)
                    } catch {
                        Log.error("FriendsModel: Error loading tracks for \(name): \(error)", category: .general)
                        return (name, nil)
                    }
                }
            }

            for await (name, tracks) in group {
                if let tracks {
                    self.friendTracks[name] = tracks
                }
            }
        }
    }
}
