//
//  FriendsViewModel.swift
//  scrobble
//
//  Created by Brett Henderson on 1/2/25.
//

import Foundation
import Combine


class FriendsViewModel: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var friendTracks: [String: [RecentTracksResponse.RecentTracks.Track]] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var lastFmManager: LastFmManagerType
    private var cancellables = Set<AnyCancellable>()
    
    init(lastFmManager: LastFmManagerType) {
        self.lastFmManager = lastFmManager
        loadFriends()
    }
    
    func loadFriends() {
        isLoading = true
        errorMessage = nil
        
        lastFmManager.getFriends(page: 1, limit: 3)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] friends in
                self?.friends = friends
                self?.loadRecentTracksForFriends()
            })
            .store(in: &cancellables)
    }
    
    private func loadRecentTracksForFriends() {
        for friend in friends {
            lastFmManager.getRecentTracks(for: friend.name, page: 1, limit: 5)
                .receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.errorMessage = "Error loading tracks for \(friend.name): \(error.localizedDescription)"
                    }
                }, receiveValue: { [weak self] tracks in
                    self?.friendTracks[friend.name] = tracks
                })
                .store(in: &cancellables)
        }
    }
    
    func refreshData() {
        loadFriends()
    }
    
    func updateLastFmManager(_ manager: LastFmManagerType) {
        self.lastFmManager = manager
        loadFriends()
    }
}
