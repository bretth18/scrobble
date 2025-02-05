//
//  PreferencesManager.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation

class PreferencesManager: ObservableObject {
    @Published var apiKey: String {
        didSet { UserDefaults.standard.set(apiKey, forKey: "lastFmApiKey") }
    }
    @Published var apiSecret: String {
        didSet { UserDefaults.standard.set(apiSecret, forKey: "lastFmApiSecret") }
    }
    @Published var username: String {
        didSet { UserDefaults.standard.set(username, forKey: "lastFmUsername") }
    }
    @Published var password: String {
        didSet { UserDefaults.standard.set(password, forKey: "lastFmPassword") }
    }
    @Published var numberOfFriendsDisplayed: Int {
        didSet { UserDefaults.standard.set(numberOfFriendsDisplayed, forKey: "numberOfFriendsDisplayed")}
    }
    
    init() {
        apiKey = UserDefaults.standard.string(forKey: "lastFmApiKey") ?? ""
        apiSecret = UserDefaults.standard.string(forKey: "lastFmApiSecret") ?? ""
        username = UserDefaults.standard.string(forKey: "lastFmUsername") ?? ""
        password = UserDefaults.standard.string(forKey: "lastFmPassword") ?? ""
        numberOfFriendsDisplayed = UserDefaults.standard.integer(forKey: "numberOfFriendsDisplayed") ?? 3
    }
}
