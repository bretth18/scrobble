//
//  PreferencesManager.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import AppKit

class PreferencesManager: ObservableObject {
    let apiKey = "70d4b4448efbe1f95036d2653a5c9e2d"
    let apiSecret = "cd31e625c60fd33ce487761130613d5d"
    

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
//        apiKey = UserDefaults.standard.string(forKey: "lastFmApiKey") ?? ""
//        apiSecret = UserDefaults.standard.string(forKey: "lastFmApiSecret") ?? ""
        username = UserDefaults.standard.string(forKey: "lastFmUsername") ?? ""
        password = UserDefaults.standard.string(forKey: "lastFmPassword") ?? ""
        numberOfFriendsDisplayed = UserDefaults.standard.integer(forKey: "numberOfFriendsDisplayed") ?? 3
    }
    
    func showPreferences() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "preferences" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    func showMainWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
