//
//  TrackMetadataResolver.swift
//  scrobble
//
//  Confirms embedded-artist split candidates for web-source tracks against
//  Last.fm before they're adopted (#12). Deterministic cleaning stays in
//  TrackMetadataCleaner — anything that touches the network lives here.
//
//  Request discipline: candidates only exist for ambiguous web titles, the
//  dwell delay skips lookups while the user flips through a playlist, at
//  most three lookups run per track, and results (including definitive
//  no-matches) are cached. The failure mode is always the status quo:
//  resolution can leave metadata unfixed, never make it worse.
//

import Foundation

actor TrackMetadataResolver {

    struct ResolvedTrack: Equatable, Sendable {
        let artist: String
        let title: String
        let album: String?
    }

    enum Outcome: Equatable, Sendable {
        /// Last.fm confirmed a candidate — adopt its canonical fields.
        case confirmed(ResolvedTrack)
        /// Definitive: no candidates, or none confirmed. Cached.
        case keepOriginal
        /// Transport failure or cancellation. Not cached, so a flaky moment
        /// never permanently marks a track unresolvable.
        case unavailable
    }

    private static let maxLookupsPerTrack = 3
    private static let cacheLimit = 500

    private let listenerThreshold: Int
    private let dwell: Duration
    private let lookup: @Sendable (String, String) async throws -> LastFmCatalogClient.TrackMatch?

    private struct CacheKey: Hashable {
        let artist: String
        let title: String
    }

    private struct CacheEntry {
        let outcome: Outcome
        var lastUsed: UInt64
    }

    private var cache: [CacheKey: CacheEntry] = [:]
    private var useCounter: UInt64 = 0

    init(
        lookup: @escaping @Sendable (String, String) async throws -> LastFmCatalogClient.TrackMatch?,
        dwell: Duration = .seconds(10),
        listenerThreshold: Int = 5
    ) {
        self.lookup = lookup
        self.dwell = dwell
        self.listenerThreshold = listenerThreshold
    }

    init(client: LastFmCatalogClient) {
        self.init(lookup: { try await client.lookupTrack(artist: $0, title: $1) })
    }

    /// `title`/`artist` are the *cleaned* fields from TrackMetadataCleaner —
    /// keying the cache on them lets junk-variant re-uploads share an entry.
    func resolve(title: String, artist: String) async -> Outcome {
        let candidates = TrackMetadataCleaner.embeddedArtistCandidates(title: title, artist: artist)
        guard !candidates.isEmpty else { return .keepOriginal }

        let key = CacheKey(artist: artist.lowercased(), title: title.lowercased())
        if var hit = cache[key] {
            useCounter += 1
            hit.lastUsed = useCounter
            cache[key] = hit
            return hit.outcome
        }

        // Dwell before spending a request — the owning task is cancelled on
        // track change, so skipping through a playlist costs nothing.
        do {
            try await Task.sleep(for: dwell)
        } catch {
            return .unavailable
        }

        for candidate in candidates.prefix(Self.maxLookupsPerTrack) {
            guard !Task.isCancelled else { return .unavailable }

            let match: LastFmCatalogClient.TrackMatch?
            do {
                match = try await lookup(candidate.artist, candidate.title)
            } catch {
                Log.debug("Metadata lookup unavailable: \(error.localizedDescription)", category: .network)
                return .unavailable
            }

            // Last.fm creates track pages from any scrobble, including other
            // apps' garbage — existence alone is weak evidence for a blind
            // guess. A structural parse plus a catalog match is strong
            // evidence, so confident candidates accept any match, even when
            // the listeners field is absent from the response.
            if let match, candidate.confident || match.listeners >= listenerThreshold {
                let outcome = Outcome.confirmed(ResolvedTrack(
                    artist: match.artist,
                    title: match.title,
                    album: match.album
                ))
                store(outcome, for: key)
                return outcome
            }
        }

        // Feeds the pattern lists: real-world shapes we don't handle yet
        // show up here.
        Log.debug("Web track unresolved: title=\"\(title)\" artist=\"\(artist)\"", category: .network)
        store(.keepOriginal, for: key)
        return .keepOriginal
    }

    private func store(_ outcome: Outcome, for key: CacheKey) {
        if cache.count >= Self.cacheLimit {
            // Evict the least-recently-used 10% in one pass — O(n log n)
            // over ~500 entries, at most once per ~50 inserts.
            let evictions = cache
                .sorted { $0.value.lastUsed < $1.value.lastUsed }
                .prefix(Self.cacheLimit / 10)
            for (evictKey, _) in evictions {
                cache.removeValue(forKey: evictKey)
            }
        }
        useCounter += 1
        cache[key] = CacheEntry(outcome: outcome, lastUsed: useCounter)
    }
}
