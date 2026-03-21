import Testing
@testable import scrobble

@Suite("SupportedMusicApp Tests")
struct SupportedMusicAppTests {

    @Test("allApps contains expected number of apps")
    func allAppsCount() {
        #expect(SupportedMusicApp.allApps.count == 4)
    }

    @Test("findApp by known bundle IDs returns correct apps")
    func findAppByKnownBundleId() {
        let appleMusic = SupportedMusicApp.findApp(byBundleId: "com.apple.Music")
        #expect(appleMusic != nil)
        #expect(appleMusic?.displayName == "Apple Music")

        let spotify = SupportedMusicApp.findApp(byBundleId: "com.spotify.client")
        #expect(spotify != nil)
        #expect(spotify?.displayName == "Spotify")

        let safari = SupportedMusicApp.findApp(byBundleId: "com.apple.safari")
        #expect(safari != nil)
        #expect(safari?.displayName == "Safari")

        let anyApp = SupportedMusicApp.findApp(byBundleId: "any")
        #expect(anyApp != nil)
        #expect(anyApp?.displayName == "Any App")
    }

    @Test("findApp by unknown bundle ID returns nil")
    func findAppByUnknownBundleId() {
        let result = SupportedMusicApp.findApp(byBundleId: "com.unknown.app")
        #expect(result == nil)
    }

    @Test("findApp by display name")
    func findAppByDisplayName() {
        let appleMusic = SupportedMusicApp.findApp(byName: "Apple Music")
        #expect(appleMusic?.bundleId == "com.apple.Music")

        let spotify = SupportedMusicApp.findApp(byName: "Spotify")
        #expect(spotify?.bundleId == "com.spotify.client")
    }

    @Test("findApp by alternative name")
    func findAppByAlternativeName() {
        let music = SupportedMusicApp.findApp(byName: "Music.app")
        #expect(music?.bundleId == "com.apple.Music")

        let spotifyMac = SupportedMusicApp.findApp(byName: "Spotify for Mac")
        #expect(spotifyMac?.bundleId == "com.spotify.client")
    }

    @Test("findApp by name is case insensitive")
    func findAppByNameCaseInsensitive() {
        let upper = SupportedMusicApp.findApp(byName: "APPLE MUSIC")
        #expect(upper?.bundleId == "com.apple.Music")

        let lower = SupportedMusicApp.findApp(byName: "spotify")
        #expect(lower?.bundleId == "com.spotify.client")
    }

    @Test("findApp by unknown name returns nil")
    func findAppByUnknownName() {
        let result = SupportedMusicApp.findApp(byName: "Tidal")
        #expect(result == nil)
    }

    @Test("Each app has non-empty properties")
    func appPropertiesNonEmpty() {
        for app in SupportedMusicApp.allApps {
            #expect(!app.bundleId.isEmpty)
            #expect(!app.displayName.isEmpty)
            #expect(!app.icon.isEmpty)
        }
    }

    @Test("Apple Music is first in allApps")
    func appleMusicIsFirst() {
        #expect(SupportedMusicApp.allApps.first?.bundleId == "com.apple.Music")
    }

    @Test("Any App has empty alternativeNames")
    func anyAppEmptyAlternativeNames() {
        let anyApp = SupportedMusicApp.findApp(byBundleId: "any")
        #expect(anyApp?.alternativeNames.isEmpty == true)
    }

    @Test("Each app has unique bundle ID")
    func uniqueBundleIds() {
        let bundleIds = SupportedMusicApp.allApps.map(\.bundleId)
        #expect(Set(bundleIds).count == bundleIds.count)
    }

    @Test("SupportedMusicApp round-trips through Codable")
    func codableRoundTrip() throws {
        let app = SupportedMusicApp.allApps.first!
        let data = try JSONEncoder().encode(app)
        let decoded = try JSONDecoder().decode(SupportedMusicApp.self, from: data)
        #expect(decoded.bundleId == app.bundleId)
        #expect(decoded.displayName == app.displayName)
        #expect(decoded.icon == app.icon)
    }
}
