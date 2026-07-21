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

        for separator in [" - ", " – ", " — ", " | "] {
            let prefix = lowerArtist + separator
            if lowerTitle.hasPrefix(prefix), title.count > prefix.count {
                return String(title.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return title
    }
}
