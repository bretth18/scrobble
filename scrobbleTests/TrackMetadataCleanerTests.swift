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

    // MARK: - Embedded artist candidates

    @Test("VNRD case: channel artist with 'Artist - Title' in the title")
    func vnrdCandidate() {
        let candidates = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Distant Strangers - Do Anything", artist: "VNRD")
        #expect(candidates.first == .init(artist: "Distant Strangers", title: "Do Anything"))
    }

    @Test("No candidates when the artist already appears in the title")
    func noCandidateWhenPrefixRuleOwns() {
        #expect(TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Gone - Bin Days", artist: "Gone").isEmpty)
    }

    @Test("Junk suffixes are stripped before candidate generation")
    func candidateAfterJunkStrip() {
        let candidates = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Distant Strangers - Do Anything (Official Video)", artist: "VNRD")
        #expect(candidates.first == .init(artist: "Distant Strangers", title: "Do Anything"))
    }

    @Test("Alternate separators produce candidates")
    func alternateSeparators() {
        #expect(TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Distant Strangers – Do Anything", artist: "VNRD").first ==
            .init(artist: "Distant Strangers", title: "Do Anything"))
        #expect(TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Distant Strangers // Do Anything", artist: "VNRD").first ==
            .init(artist: "Distant Strangers", title: "Do Anything"))
    }

    @Test("Multi-separator titles yield first-split and second-split candidates")
    func multiSeparator() {
        let candidates = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Ninja Tune - Bonobo - Kerala", artist: "SomeChannel")
        #expect(candidates.count == 2)
        #expect(candidates[0] == .init(artist: "Ninja Tune", title: "Bonobo - Kerala"))
        #expect(candidates[1] == .init(artist: "Bonobo", title: "Kerala"))
    }

    @Test("Quoted-title style yields a candidate")
    func quotedTitle() {
        let candidates = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Spiritbox \"Circle With Me\"", artist: "Century Media Records")
        #expect(candidates.contains(.init(artist: "Spiritbox", title: "Circle With Me", confident: true)))
    }

    @Test("Separator plus quoted title tidies the quotes away")
    func separatorWithQuotes() {
        let candidates = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Spiritbox - \"Circle With Me\"", artist: "Century Media Records")
        #expect(candidates.first == .init(artist: "Spiritbox", title: "Circle With Me"))
    }

    @Test("Version descriptor marks its side as the title")
    func versionDescriptorSignal() {
        // Reversed shape: "Title Original Mix - Artist"
        let reversed = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Don't Think Too Much Original Mix - Cloak & Dagger",
            artist: "Johnathan Yelenick")
        #expect(reversed == [
            .init(artist: "Cloak & Dagger", title: "Don't Think Too Much (Original Mix)", confident: true),
            .init(artist: "Cloak & Dagger", title: "Don't Think Too Much", confident: true),
            .init(artist: "Cloak & Dagger", title: "Don't Think Too Much Original Mix", confident: true),
        ])

        // Forward shape: "Artist - Title Radio Edit"
        let forward = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Cloak & Dagger - Don't Think Too Much Radio Edit",
            artist: "SomeChannel")
        #expect(forward.first == .init(artist: "Cloak & Dagger", title: "Don't Think Too Much (Radio Edit)", confident: true))
    }

    @Test("Two-part titles without a signal get forward and reversed candidates")
    func reversedFallback() {
        let candidates = TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Do Anything - Distant Strangers", artist: "VNRD")
        #expect(candidates == [
            .init(artist: "Do Anything", title: "Distant Strangers"),
            .init(artist: "Distant Strangers", title: "Do Anything"),
        ])
    }

    @Test("Plain titles produce no candidates")
    func noSeparatorNoCandidates() {
        #expect(TrackMetadataCleaner.embeddedArtistCandidates(
            title: "Do Anything", artist: "VNRD").isEmpty)
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
