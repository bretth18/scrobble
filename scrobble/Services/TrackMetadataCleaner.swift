//
//  TrackMetadataCleaner.swift
//  scrobble
//
//  Created by Brett Henderson on 7/21/26.
//

import Foundation

enum TrackMetadataCleaner {

    // MARK: - Web source detection

    private static let browserBundleIDs: Set<String> = [
        "com.apple.safari",
        "com.apple.safaritechnologypreview",
        "com.google.chrome",
        "com.google.chrome.canary",
        "org.chromium.chromium",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.browser",
        "company.thebrowser.browser",
        "com.vivaldi.vivaldi",
        "com.operasoftware.opera",
        "app.zen-browser.zen",
    ]

    private static let browserNames: Set<String> = [
        "safari", "chrome", "google chrome", "chromium", "firefox",
        "microsoft edge", "brave browser", "arc", "vivaldi", "opera", "zen",
    ]

    static func isWebSource(bundleIdentifier: String?, applicationName: String) -> Bool {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return browserBundleIDs.contains(bundleIdentifier.lowercased())
        }
        return browserNames.contains(applicationName.lowercased())
    }

    // MARK: - Cleaning

    /// Applies web cleanup only when the source is a browser; otherwise
    /// returns the fields untouched.
    static func cleanIfWebSource(
        title: String, artist: String, album: String,
        bundleIdentifier: String?, applicationName: String
    ) -> (title: String, artist: String, album: String) {
        guard isWebSource(bundleIdentifier: bundleIdentifier, applicationName: applicationName) else {
            return (title, artist, album)
        }
        return clean(title: title, artist: artist, album: album)
    }

    static func clean(title: String, artist: String, album: String) -> (title: String, artist: String, album: String) {
        let cleanedArtist = cleanArtist(artist)
        var cleanedTitle = stripJunkSuffixes(from: title)
        cleanedTitle = stripArtistPrefix(from: cleanedTitle, artist: cleanedArtist)

        // If a rule reduced a field to nothing, the original was better than
        // an empty scrobble field.
        return (
            title: cleanedTitle.isEmpty ? title : cleanedTitle,
            artist: cleanedArtist.isEmpty ? artist : cleanedArtist,
            album: album
        )
    }

    /// YouTube auto-generated channels ("Artist - Topic") and VEVO channels
    /// ("ArtistVEVO").
    private static func cleanArtist(_ artist: String) -> String {
        var cleaned = artist.trimmingCharacters(in: .whitespaces)

        for separator in [" - topic", " – topic", " — topic"] {
            if cleaned.lowercased().hasSuffix(separator) {
                cleaned = String(cleaned.dropLast(separator.count))
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        if cleaned.hasSuffix("VEVO"), cleaned.count > 4 {
            cleaned = String(cleaned.dropLast(4)).trimmingCharacters(in: .whitespaces)
        }

        return cleaned
    }

    /// Trailing bracketed decorations only — "(Official Video)", "[HD]", …
    /// Loops so stacked suffixes like "(Official Video) [HD]" fully unwind.
    private static let junkTitleSuffix = try! NSRegularExpression(
        pattern: #"\s*[\(\[](?:official\s+)?(?:music\s+video|lyric\s+video|video|audio|lyrics|visuali[sz]er|hd|hq|4k)[\)\]]\s*$"#,
        options: [.caseInsensitive]
    )

    private static func stripJunkSuffixes(from title: String) -> String {
        var cleaned = title.trimmingCharacters(in: .whitespaces)
        while true {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            guard let match = junkTitleSuffix.firstMatch(in: cleaned, range: range),
                  let matchRange = Range(match.range, in: cleaned) else {
                break
            }
            cleaned.removeSubrange(matchRange)
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        }
        return cleaned
    }

    /// "Artist - Title" video naming: strip the artist prefix from the title
    /// only when it exactly matches the (cleaned) artist field.
    private static func stripArtistPrefix(from title: String, artist: String) -> String {
        guard !artist.isEmpty else { return title }
        let lowerTitle = title.lowercased()
        let lowerArtist = artist.lowercased()

        for separator in separators {
            let prefix = lowerArtist + separator
            if lowerTitle.hasPrefix(prefix), title.count > prefix.count {
                return String(title.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return title
    }

    // MARK: - Embedded artist candidates

    /// A possible (artist, title) reading of a web title like
    /// "Distant Strangers - Do Anything" uploaded by an unrelated channel.
    /// `confident` marks structural parses (version descriptor, quotes).
    /// The resolver accepts those on a bare catalog match; blind guesses
    /// need more listeners.
    struct SplitCandidate: Equatable {
        let artist: String
        let title: String
        var confident: Bool = false
    }

    private static let separators = [" - ", " – ", " — ", " | ", " // "]

    /// Ordered, liberal candidate generation. Candidates decide nothing on
    /// their own — TrackMetadataResolver adopts one only after Last.fm
    /// confirms it, so a wrong candidate costs a request, never accuracy.
    static func embeddedArtistCandidates(title: String, artist: String) -> [SplitCandidate] {
        let cleanedTitle = stripJunkSuffixes(from: title)

        // If the artist field already appears in the title, the prefix rule
        // owns this case; a channel-name artist won't.
        if !artist.isEmpty, cleanedTitle.lowercased().contains(artist.lowercased()) {
            return []
        }

        var candidates: [SplitCandidate] = []
        let parts = splitOnSeparators(cleanedTitle)

        if parts.count == 2 {
            candidates += pairCandidates(left: tidy(parts[0]), right: tidy(parts[1]))
        } else if parts.count >= 3 {
            // "Artist - Title - …"
            candidates.append(SplitCandidate(
                artist: tidy(parts[0]),
                title: tidy(parts.dropFirst().joined(separator: " - "))
            ))
            // "Label - Artist - Title"
            candidates.append(SplitCandidate(
                artist: tidy(parts[1]),
                title: tidy(parts.dropFirst(2).joined(separator: " - "))
            ))
        }
        // 'Artist "Title"' quoted style (no separator required).
        if let quoted = quotedTitleCandidate(from: cleanedTitle) {
            candidates.append(quoted)
        }

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard !candidate.artist.isEmpty, !candidate.title.isEmpty else { return false }
            return seen.insert("\(candidate.artist.lowercased())|\(candidate.title.lowercased())").inserted
        }
    }

    /// Candidates for a two-part title. An unbracketed trailing version
    /// descriptor marks that side as the title — artists do not end with
    /// "Original Mix". The descriptor side gets three title variants:
    /// parenthesized, stripped, verbatim.
    private static func pairCandidates(left: String, right: String) -> [SplitCandidate] {
        let leftVersion = trailingVersion(left)
        let rightVersion = trailingVersion(right)

        if let version = leftVersion, rightVersion == nil {
            // "Title Original Mix - Artist"
            return titleVariants(artist: right, version: version, verbatim: left)
        }
        if let version = rightVersion, leftVersion == nil {
            // "Artist - Title Original Mix"
            return titleVariants(artist: left, version: version, verbatim: right)
        }
        // No signal: forward first, reversed second.
        return [
            SplitCandidate(artist: left, title: right),
            SplitCandidate(artist: right, title: left),
        ]
    }

    private static func titleVariants(
        artist: String, version: (base: String, descriptor: String), verbatim: String
    ) -> [SplitCandidate] {
        [
            SplitCandidate(artist: artist, title: "\(version.base) (\(version.descriptor))", confident: true),
            SplitCandidate(artist: artist, title: version.base, confident: true),
            SplitCandidate(artist: artist, title: verbatim, confident: true),
        ]
    }

    private static let versionDescriptors = [
        "original mix", "extended mix", "radio edit", "club mix",
        "dub mix", "vip mix", "instrumental mix", "extended version",
    ]

    private static func trailingVersion(_ part: String) -> (base: String, descriptor: String)? {
        let lower = part.lowercased()
        for descriptor in versionDescriptors {
            let suffix = " " + descriptor
            if lower.hasSuffix(suffix), part.count > suffix.count {
                let base = String(part.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                let original = String(part.suffix(descriptor.count))
                if !base.isEmpty { return (base, original) }
            }
        }
        return nil
    }

    /// Parse-only normalization: splits on any separator variant. The parts
    /// are lookup inputs, never submitted text — on confirmation the
    /// resolver adopts Last.fm's canonical fields instead.
    private static func splitOnSeparators(_ text: String) -> [String] {
        var normalized = text
        for separator in separators.dropFirst() {
            normalized = normalized.replacingOccurrences(of: separator, with: separators[0])
        }
        return normalized.components(separatedBy: separators[0])
    }

    private static let quotedTitle = try! NSRegularExpression(
        pattern: #"^(.+?)\s+["“](.+?)["”]$"#,
        options: []
    )

    private static func quotedTitleCandidate(from title: String) -> SplitCandidate? {
        let range = NSRange(title.startIndex..., in: title)
        guard let match = quotedTitle.firstMatch(in: title, range: range),
              let artistRange = Range(match.range(at: 1), in: title),
              let titleRange = Range(match.range(at: 2), in: title) else {
            return nil
        }
        return SplitCandidate(
            artist: tidy(String(title[artistRange])),
            title: tidy(String(title[titleRange])),
            confident: true
        )
    }

    /// Trims whitespace and matched surrounding double quotes. Single quotes
    /// are left alone — trailing apostrophes ("Rockin'") are real.
    private static func tidy(_ text: String) -> String {
        var tidied = text.trimmingCharacters(in: .whitespaces)
        let quotes: Set<Character> = ["\"", "\u{201C}", "\u{201D}", "\u{201E}", "«", "»"]
        while tidied.count >= 2,
              let first = tidied.first, let last = tidied.last,
              quotes.contains(first), quotes.contains(last) {
            tidied = String(tidied.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespaces)
        }
        return tidied
    }
}
