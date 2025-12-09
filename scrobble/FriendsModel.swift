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
        print("FriendsModel: Loading friends...")
        isLoading = true
        errorMessage = nil
        
        let limit = preferencesManager?.numberOfFriendsDisplayed ?? 10
        print("FriendsModel: Fetching \(limit) friends")
        
        lastFmManager.getFriends(page: 1, limit: limit)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                guard let self = self else { return }
                self.isLoading = false
                
                if case .failure(let error) = completion {
                    print("FriendsModel: Error loading friends: \(error)")
                    // Check for specific error about missing parameters
                    if error.localizedDescription.contains("Missing parameter") {
                         self.errorMessage = "Configuration error: Missing username or API key."
                    } else {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] friends in
                guard let self = self else { return }
                print("FriendsModel: Loaded \(friends.count) friends")
                self.friends = friends
                self.loadRecentTracksForFriends()
            })
            .store(in: &cancellables)
    }
    
    private func loadRecentTracksForFriends() {
        guard !friends.isEmpty else { return }
        print("FriendsModel: Loading recent tracks for \(friends.count) friends")
        
        // Clear old tracks just in case, or keep them? 
        // Better to update incrementally or clear? Let's keep existing if refreshing.
        
        for friend in friends {
            lastFmManager.getRecentTracks(for: friend.name, page: 1, limit: 1)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        print("FriendsModel: Error loading tracks for \(friend.name): \(error)")
                    }
                }, receiveValue: { [weak self] tracks in
                    self?.friendTracks[friend.name] = tracks
                })
                .store(in: &cancellables)
        }
    }
}
