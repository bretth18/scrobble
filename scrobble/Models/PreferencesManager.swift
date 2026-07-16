//
//  PreferencesManager.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import Foundation
import AppKit
import Observation

/// Wraps a UserDefaults-backed value with @Observable change tracking.
/// This avoids relying on `didSet` which can break with the @Observable macro.
@propertyWrapper
struct DefaultsBacked<Value> {
    let key: String
    let defaultValue: Value
    let store: UserDefaults

    init(wrappedValue: Value, _ key: String, store: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = wrappedValue
        self.store = store
    }

    var wrappedValue: Value {
        get {
            store.object(forKey: key).flatMap { $0 as? Value } ?? defaultValue
        }
        set {
            store.set(newValue, forKey: key)
        }
    }
}

@Observable
@MainActor
class PreferencesManager {
    // Standard access for secrets
    var apiKey: String { Secrets.lastFmApiKey }
    var apiSecret: String { Secrets.lastFmApiSecret }

    @ObservationIgnored @DefaultsBacked("lastFmUsername")
    private var _username: String = ""
    var username: String {
        get {
            access(keyPath: \.username)
            return _username
        }
        set {
            withMutation(keyPath: \.username) {
                _username = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("numberOfFriendsDisplayed")
    private var _numberOfFriendsDisplayed: Int = 10
    var numberOfFriendsDisplayed: Int {
        get {
            access(keyPath: \.numberOfFriendsDisplayed)
            return _numberOfFriendsDisplayed
        }
        set {
            withMutation(keyPath: \.numberOfFriendsDisplayed) {
                _numberOfFriendsDisplayed = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("numberOfFriendsRecentTracksDisplayed")
    private var _numberOfFriendsRecentTracksDisplayed: Int = 5
    var numberOfFriendsRecentTracksDisplayed: Int {
        get {
            access(keyPath: \.numberOfFriendsRecentTracksDisplayed)
            return _numberOfFriendsRecentTracksDisplayed
        }
        set {
            withMutation(keyPath: \.numberOfFriendsRecentTracksDisplayed) {
                _numberOfFriendsRecentTracksDisplayed = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("trackCompletionPercentageBeforeScrobble")
    private var _trackCompletionPercentageBeforeScrobble: Int = 50
    var trackCompletionPercentageBeforeScrobble: Int {
        get {
            access(keyPath: \.trackCompletionPercentageBeforeScrobble)
            return _trackCompletionPercentageBeforeScrobble
        }
        set {
            withMutation(keyPath: \.trackCompletionPercentageBeforeScrobble) {
                _trackCompletionPercentageBeforeScrobble = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("useMaxTrackCompletionScrobbleDelay")
    private var _useMaxTrackCompletionScrobbleDelay: Bool = true
    var useMaxTrackCompletionScrobbleDelay: Bool {
        get {
            access(keyPath: \.useMaxTrackCompletionScrobbleDelay)
            return _useMaxTrackCompletionScrobbleDelay
        }
        set {
            withMutation(keyPath: \.useMaxTrackCompletionScrobbleDelay) {
                _useMaxTrackCompletionScrobbleDelay = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("maxTrackCompletionScrobbleDelay")
    private var _maxTrackCompletionScrobbleDelay: Int = 240
    var maxTrackCompletionScrobbleDelay: Int {
        get {
            access(keyPath: \.maxTrackCompletionScrobbleDelay)
            return _maxTrackCompletionScrobbleDelay
        }
        set {
            withMutation(keyPath: \.maxTrackCompletionScrobbleDelay) {
                _maxTrackCompletionScrobbleDelay = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("mediaAppSource")
    private var _mediaAppSource: String = "Apple Music"
    var mediaAppSource: String {
        get {
            access(keyPath: \.mediaAppSource)
            return _mediaAppSource
        }
        set {
            withMutation(keyPath: \.mediaAppSource) {
                _mediaAppSource = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("enableLastFm")
    private var _enableLastFm: Bool = true
    var enableLastFm: Bool {
        get {
            access(keyPath: \.enableLastFm)
            return _enableLastFm
        }
        set {
            withMutation(keyPath: \.enableLastFm) {
                _enableLastFm = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("launchAtLogin")
    private var _launchAtLogin: Bool = false
    var launchAtLogin: Bool {
        get {
            access(keyPath: \.launchAtLogin)
            return _launchAtLogin
        }
        set {
            withMutation(keyPath: \.launchAtLogin) {
                _launchAtLogin = newValue
            }
        }
    }

    @ObservationIgnored @DefaultsBacked("showDockIcon")
    private var _showDockIcon: Bool = false
    var showDockIcon: Bool {
        get {
            access(keyPath: \.showDockIcon)
            return _showDockIcon
        }
        set {
            withMutation(keyPath: \.showDockIcon) {
                _showDockIcon = newValue
            }
            Self.applyActivationPolicy(showDockIcon: newValue)
            // Keep the Settings window frontmost across the policy change.
            NSApp.activate()
        }
    }

    /// The app ships as LSUIElement (no Dock icon). Switching to `.regular`
    /// restores the Dock icon when the user opts in.
    static func applyActivationPolicy(
        showDockIcon: Bool = UserDefaults.standard.bool(forKey: "showDockIcon")
    ) {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    @ObservationIgnored @DefaultsBacked("selectedMusicAppBundleId")
    private var _selectedMusicAppBundleId: String = "com.apple.Music"
    var selectedMusicApp: SupportedMusicApp {
        get {
            access(keyPath: \.selectedMusicApp)
            return SupportedMusicApp.findApp(byBundleId: _selectedMusicAppBundleId)
                ?? SupportedMusicApp.allApps.first(where: { $0.bundleId == "com.apple.Music" })!
        }
        set {
            withMutation(keyPath: \.selectedMusicApp) {
                _selectedMusicAppBundleId = newValue.bundleId
                _mediaAppSource = newValue.displayName
            }
        }
    }

    init() {
        // Clean up legacy password storage
        UserDefaults.standard.removeObject(forKey: "lastFmPassword")
        // Clean up prefs from the removed ScrobbleProtocol (Bluesky) service
        UserDefaults.standard.removeObject(forKey: "enableCustomScrobbler")
        UserDefaults.standard.removeObject(forKey: "blueskyHandle")
    }
}
