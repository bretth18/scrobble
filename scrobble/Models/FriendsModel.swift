//
//  FriendsModel.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import Combine
import Observation

@Observable
class FriendsModel {
    var friends: [Friend] = []
    var friendTracks: [String: [RecentTracksResponse.RecentTracks.Track]] = [:]
    var isLoading = false
    var errorMessage: String?
    
    var preferencesManager: PreferencesManager?
    
    private var lastFmManager: LastFmManagerType
    private var cancellables = Set<AnyCancellable>()
    
    init(lastFmManager: LastFmManagerType) {
        self.lastFmManager = lastFmManager
    }
    
    func updateLastFmManager(_ manager: LastFmManagerType) {
        self.lastFmManager = manager
        loadFriends()
    }
    
    func refreshData() {
        loadFriends()
    }
    
    // Using a separate method to keep init lightweight
    func loadFriends() {
        Log.debug("FriendsModel: Loading friends...", category: .general)
        isLoading = true
        errorMessage = nil
        
        let limit = preferencesManager?.numberOfFriendsDisplayed ?? 10
        Log.debug("FriendsModel: Fetching \(limit) friends", category: .general)
        
        lastFmManager.getFriends(page: 1, limit: limit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    Log.error("FriendsModel: Error loading friends: \(error)", category: .general)
                    // Check for specific error about missing parameters
                    if error.localizedDescription.contains("Missing parameter") {
                         self.errorMessage = "Configuration error: Missing username or API key."
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] friends in
                guard let self = self else { return }
                Log.debug("FriendsModel: Loaded \(friends.count) friends", category: .general)
                self.friends = friends
                self.loadRecentTracksForFriends()
            })
            .store(in: &cancellables)
    }
    
    private func loadRecentTracksForFriends() {
        guard !friends.isEmpty else { return }
        Log.debug("FriendsModel: Loading recent tracks for \(friends.count) friends", category: .general)
        
        // Clear old tracks just in case, or keep them? 
        // Better to update incrementally or clear? Let's keep existing if refreshing.
        
        // get limit from pref manager
        let limit = preferencesManager?.numberOfFriendsRecentTracksDisplayed ?? 3
        
        
        for friend in friends {
            lastFmManager.getRecentTracks(for: friend.name, page: 1, limit: limit)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        Log.error("FriendsModel: Error loading tracks for \(friend.name): \(error)", category: .general)
                    }
                }, receiveValue: { [weak self] tracks in
                    self?.friendTracks[friend.name] = tracks
                })
                .store(in: &cancellables)
        }
    }
}
