import Testing
@testable import scrobble

@Suite("TrackMetadataCleaner")
struct TrackMetadataCleanerTests {

    // The exact scenario from issue #12: YouTube embed metadata.
    @Test("Issue #12: Topic channel artist and artist-prefixed title")
    func issueExample() {
        let result = TrackMetadataCleaner.clean(
            title: "Gone - Bin Days (Official Video)",
            artist: "Gone - Topic",
            album: ""
        )
        #expect(result.title == "Bin Days")
        #expect(result.artist == "Gone")
    }

    @Test("Strips ' - Topic' suffix from artist")
    func topicSuffix() {
        #expect(TrackMetadataCleaner.clean(title: "T", artist: "Boards of Canada - Topic", album: "").artist == "Boards of Canada")
        #expect(TrackMetadataCleaner.clean(title: "T", artist: "Burial – Topic", album: "").artist == "Burial")
    }

    @Test("Strips VEVO suffix from artist")
    func vevoSuffix() {
        #expect(TrackMetadataCleaner.clean(title: "T", artist: "RihannaVEVO", album: "").artist == "Rihanna")
        // "VEVO" alone must not become empty
        #expect(TrackMetadataCleaner.clean(title: "T", artist: "VEVO", album: "").artist == "VEVO")
    }

    @Test("Strips trailing junk brackets from title, including stacked ones")
    func junkTitleSuffixes() {
        #expect(TrackMetadataCleaner.clean(title: "Song (Official Music Video)", artist: "A", album: "").title == "Song")
        #expect(TrackMetadataCleaner.clean(title: "Song [Official Audio]", artist: "A", album: "").title == "Song")
        #expect(TrackMetadataCleaner.clean(title: "Song (Lyric Video)", artist: "A", album: "").title == "Song")
        #expect(TrackMetadataCleaner.clean(title: "Song (Official Video) [HD]", artist: "A", album: "").title == "Song")
        #expect(TrackMetadataCleaner.clean(title: "Song (Visualizer)", artist: "A", album: "").title == "Song")
    }

    @Test("Preserves meaningful segments and mid-title brackets")
    func meaningfulSegmentsPreserved() {
        #expect(TrackMetadataCleaner.clean(title: "Song (Live)", artist: "A", album: "").title == "Song (Live)")
        #expect(TrackMetadataCleaner.clean(title: "Song (feat. B)", artist: "A", album: "").title == "Song (feat. B)")
        #expect(TrackMetadataCleaner.clean(title: "Song (Remix)", artist: "A", album: "").title == "Song (Remix)")
        // "(Audio)" mid-title is not a suffix — untouched
        #expect(TrackMetadataCleaner.clean(title: "Song (Audio) Part 2", artist: "A", album: "").title == "Song (Audio) Part 2")
    }

    @Test("Strips artist prefix from title only on exact artist match")
    func artistPrefix() {
        #expect(TrackMetadataCleaner.clean(title: "Gone - Bin Days", artist: "Gone", album: "").title == "Bin Days")
        // Different artist in the prefix — leave the title alone
        #expect(TrackMetadataCleaner.clean(title: "Someone Else - Bin Days", artist: "Gone", album: "").title == "Someone Else - Bin Days")
        // Hyphenated titles without the artist stay intact
        #expect(TrackMetadataCleaner.clean(title: "T-Shirt Weather", artist: "Circa Waves", album: "").title == "T-Shirt Weather")
    }

    @Test("Never produces empty fields — falls back to the original")
    func emptyFallback() {
        let result = TrackMetadataCleaner.clean(title: "(Official Video)", artist: "", album: "")
        #expect(result.title == "(Official Video)")
    }

    @Test("Album passes through unchanged")
    func albumUntouched() {
        #expect(TrackMetadataCleaner.clean(title: "T", artist: "A", album: "Some Album").album == "Some Album")
    }

    @Test("Web source detection by bundle identifier")
    func webSourceDetection() {
        #expect(TrackMetadataCleaner.isWebSource(bundleIdentifier: "com.apple.Safari", applicationName: "Safari"))
        #expect(TrackMetadataCleaner.isWebSource(bundleIdentifier: "com.google.Chrome", applicationName: "Google Chrome"))
        #expect(!TrackMetadataCleaner.isWebSource(bundleIdentifier: "com.apple.Music", applicationName: "Music"))
        #expect(!TrackMetadataCleaner.isWebSource(bundleIdentifier: "com.spotify.client", applicationName: "Spotify"))
        // Name fallback when bundle id is missing
        #expect(TrackMetadataCleaner.isWebSource(bundleIdentifier: nil, applicationName: "Safari"))
        #expect(!TrackMetadataCleaner.isWebSource(bundleIdentifier: nil, applicationName: "Music"))
    }

    @Test("Native sources pass through cleanIfWebSource untouched")
    func nativeGating() {
        let result = TrackMetadataCleaner.cleanIfWebSource(
            title: "Song - Topic Mix (Official Video)",
            artist: "Artist - Topic",
            album: "",
            bundleIdentifier: "com.apple.Music",
            applicationName: "Music"
        )
        #expect(result.title == "Song - Topic Mix (Official Video)")
        #expect(result.artist == "Artist - Topic")
    }
}
