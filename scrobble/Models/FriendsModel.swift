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
    /// Full first page of the user's friends — backs the filter picker.
    var allFriends: [Friend] = []
    /// The displayed subset: the user's selection, or the first
    /// `numberOfFriendsDisplayed` friends when no selection exists.
    var friends: [Friend] = []
    var friendTracks: [String: [RecentTracksResponse.RecentTracks.Track]] = [:]
    var isLoading = false
    var errorMessage: String?

    private static let friendsPageSize = 50

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
        isLoading = true
        errorMessage = nil

        loadTask = Task {
            do {
                // Always fetch the full page so the filter picker has the
                // complete list; recent tracks are only fetched for the
                // displayed subset.
                let fetched = try await lastFmManager.getFriends(page: 1, limit: Self.friendsPageSize)
                guard !Task.isCancelled else { return }
                Log.debug("FriendsModel: Loaded \(fetched.count) friends", category: .network)
                self.allFriends = fetched
                self.applyFilter()
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

    /// Applies the user's friend selection (or the display-count default)
    /// to `allFriends`, producing the displayed subset.
    private func applyFilter() {
        let selected = preferencesManager?.selectedFriends ?? []
        if selected.isEmpty {
            let limit = preferencesManager?.numberOfFriendsDisplayed ?? 10
            friends = Array(allFriends.prefix(limit))
        } else {
            friends = allFriends.filter { selected.contains($0.name) }
        }
    }

    /// Called when the selection or display count changes — re-filters
    /// without a network round-trip and fetches tracks only for friends
    /// that don't have them yet.
    func selectionDidChange() {
        applyFilter()
        Task { await loadRecentTracksForFriends(onlyMissing: true) }
    }

    private func loadRecentTracksForFriends(onlyMissing: Bool = false) async {
        let targets = onlyMissing ? friends.filter { friendTracks[$0.name] == nil } : friends
        guard !targets.isEmpty else { return }
        Log.debug("FriendsModel: Loading recent tracks for \(targets.count) friends", category: .network)

        let limit = preferencesManager?.numberOfFriendsRecentTracksDisplayed ?? 3

        await withTaskGroup(of: (String, [RecentTracksResponse.RecentTracks.Track]?).self) { group in
            for friend in targets {
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
