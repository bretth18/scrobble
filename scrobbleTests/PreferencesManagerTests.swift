import Testing
@testable import scrobble

@Suite("PreferencesManager Tests", .serialized)
struct PreferencesManagerTests {

    private func cleanupDefaults() {
        let keys = [
            "lastFmUsername", "lastFmPassword", "numberOfFriendsDisplayed",
            "numberOfFriendsRecentTracksDisplayed", "trackCompletionPercentageBeforeScrobble",
            "maxTrackCompletionScrobbleDelay", "useMaxTrackCompletionScrobbleDelay",
            "mediaAppSource", "enableCustomScrobbler", "blueskyHandle",
            "enableLastFm", "launchAtLogin", "selectedMusicAppBundleId"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    @Test("Default username is empty")
    func defaultUsername() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.username == "")
    }

    @Test("Setting username persists to UserDefaults")
    func usernamePersistence() {
        cleanupDefaults()
        let manager = PreferencesManager()
        manager.username = "testuser"
        #expect(UserDefaults.standard.string(forKey: "lastFmUsername") == "testuser")
        cleanupDefaults()
    }

    @Test("Default numberOfFriendsDisplayed is 10")
    func defaultFriendsDisplayed() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.numberOfFriendsDisplayed == 10)
    }

    @Test("Default trackCompletionPercentageBeforeScrobble is 50")
    func defaultCompletionPercentage() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.trackCompletionPercentageBeforeScrobble == 50)
    }

    @Test("Default maxTrackCompletionScrobbleDelay is 240")
    func defaultMaxDelay() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.maxTrackCompletionScrobbleDelay == 240)
    }

    @Test("Default selectedMusicApp is Apple Music")
    func defaultSelectedApp() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.selectedMusicApp.bundleId == "com.apple.Music")
    }

    @Test("Setting selectedMusicApp updates mediaAppSource")
    func selectedMusicAppUpdatesMediaAppSource() {
        cleanupDefaults()
        let manager = PreferencesManager()
        let spotify = SupportedMusicApp.allApps.first(where: { $0.bundleId == "com.spotify.client" })!
        manager.selectedMusicApp = spotify
        #expect(manager.mediaAppSource == "Spotify")
        cleanupDefaults()
    }

    @Test("Default enableLastFm is true")
    func defaultEnableLastFm() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.enableLastFm == true)
    }

    @Test("Default enableCustomScrobbler is false")
    func defaultEnableCustomScrobbler() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.enableCustomScrobbler == false)
    }

    @Test("Default launchAtLogin is false")
    func defaultLaunchAtLogin() {
        cleanupDefaults()
        let manager = PreferencesManager()
        #expect(manager.launchAtLogin == false)
    }
}
