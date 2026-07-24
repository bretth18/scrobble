import Testing
import Foundation
@testable import scrobble

/// Thread-safe call recorder for the injected lookup. Test flows are
/// sequential awaits, so the unchecked wrapper is safe here.
private final class LookupRecorder: @unchecked Sendable {
    private(set) var calls: [(artist: String, title: String)] = []
    func record(_ artist: String, _ title: String) { calls.append((artist, title)) }
}

@Suite("TrackMetadataResolver")
struct TrackMetadataResolverTests {

    private static func match(
        artist: String, title: String, album: String? = nil, listeners: Int
    ) -> LastFmCatalogClient.TrackMatch {
        .init(artist: artist, title: title, album: album, listeners: listeners)
    }

    @Test("Confirms a candidate and adopts Last.fm's canonical fields")
    func confirmsCandidate() async {
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in
                Self.match(artist: artist, title: title, album: "Some Album", listeners: 1200)
            },
            dwell: .zero
        )
        let outcome = await resolver.resolve(title: "Distant Strangers - Do Anything", artist: "VNRD")
        #expect(outcome == .confirmed(.init(artist: "Distant Strangers", title: "Do Anything", album: "Some Album")))
    }

    @Test("No candidates means keepOriginal without any lookup")
    func noCandidatesNoLookup() async {
        let recorder = LookupRecorder()
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in recorder.record(artist, title); return nil },
            dwell: .zero
        )
        let outcome = await resolver.resolve(title: "Do Anything", artist: "VNRD")
        #expect(outcome == .keepOriginal)
        #expect(recorder.calls.isEmpty)
    }

    @Test("Matches below the listener threshold are rejected")
    func listenerThreshold() async {
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in Self.match(artist: artist, title: title, listeners: 1) },
            dwell: .zero
        )
        let outcome = await resolver.resolve(title: "Distant Strangers - Do Anything", artist: "VNRD")
        #expect(outcome == .keepOriginal)
    }

    @Test("Falls through to the second candidate when the first misses")
    func secondCandidate() async {
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in
                artist == "Bonobo" ? Self.match(artist: artist, title: title, listeners: 900) : nil
            },
            dwell: .zero
        )
        let outcome = await resolver.resolve(title: "Ninja Tune - Bonobo - Kerala", artist: "SomeChannel")
        #expect(outcome == .confirmed(.init(artist: "Bonobo", title: "Kerala", album: nil)))
    }

    @Test("Definitive outcomes are cached — one lookup across repeat resolves")
    func cachesDefinitiveOutcomes() async {
        let recorder = LookupRecorder()
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in
                recorder.record(artist, title)
                return Self.match(artist: artist, title: title, listeners: 50)
            },
            dwell: .zero
        )
        _ = await resolver.resolve(title: "Distant Strangers - Do Anything", artist: "VNRD")
        let second = await resolver.resolve(title: "Distant Strangers - Do Anything", artist: "VNRD")
        #expect(second == .confirmed(.init(artist: "Distant Strangers", title: "Do Anything", album: nil)))
        #expect(recorder.calls.count == 1)
    }

    @Test("No-match outcomes are cached too")
    func cachesNegatives() async {
        let recorder = LookupRecorder()
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in recorder.record(artist, title); return nil },
            dwell: .zero
        )
        _ = await resolver.resolve(title: "Obscure - Mix", artist: "SomeChannel")
        let callsAfterFirst = recorder.calls.count
        _ = await resolver.resolve(title: "Obscure - Mix", artist: "SomeChannel")
        #expect(recorder.calls.count == callsAfterFirst)
    }

    @Test("Transport failures return unavailable and are not cached")
    func failuresNotCached() async {
        let recorder = LookupRecorder()
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in
                recorder.record(artist, title)
                if recorder.calls.count == 1 { throw ScrobblerError.apiError("offline") }
                return Self.match(artist: artist, title: title, listeners: 50)
            },
            dwell: .zero
        )
        let first = await resolver.resolve(title: "Distant Strangers - Do Anything", artist: "VNRD")
        #expect(first == .unavailable)
        // The failure wasn't cached, so a fresh playback retries and succeeds.
        let second = await resolver.resolve(title: "Distant Strangers - Do Anything", artist: "VNRD")
        #expect(second == .confirmed(.init(artist: "Distant Strangers", title: "Do Anything", album: nil)))
    }

    @Test("Lookups are capped at three per track")
    func lookupCap() async {
        let recorder = LookupRecorder()
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in recorder.record(artist, title); return nil },
            dwell: .zero
        )
        _ = await resolver.resolve(title: "A - B - C \"D\"", artist: "SomeChannel")
        #expect(recorder.calls.count <= 3)
    }

    @Test("Confident candidates accept matches with zero listeners")
    func confidentLowListeners() async {
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in
                guard title == "Don't Think Too Much (Original Mix)" else { return nil }
                // Simulates a genuine track page whose listeners field is
                // absent from the response.
                return Self.match(artist: artist, title: title, listeners: 0)
            },
            dwell: .zero
        )
        let outcome = await resolver.resolve(
            title: "Don't Think Too Much Original Mix - Cloak & Dagger",
            artist: "Johnathan Yelenick"
        )
        #expect(outcome == .confirmed(.init(
            artist: "Cloak & Dagger", title: "Don't Think Too Much (Original Mix)", album: nil)))
    }

    @Test("Reversed title with unbracketed version tag resolves")
    func reversedVersionTag() async {
        let resolver = TrackMetadataResolver(
            lookup: { artist, title in
                guard artist == "Cloak & Dagger", title == "Don't Think Too Much (Original Mix)" else {
                    return nil
                }
                return Self.match(artist: artist, title: title, listeners: 300)
            },
            dwell: .zero
        )
        let outcome = await resolver.resolve(
            title: "Don't Think Too Much Original Mix - Cloak & Dagger",
            artist: "Johnathan Yelenick"
        )
        #expect(outcome == .confirmed(.init(
            artist: "Cloak & Dagger", title: "Don't Think Too Much (Original Mix)", album: nil)))
    }
}
