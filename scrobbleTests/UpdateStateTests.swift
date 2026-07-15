import Testing
import Foundation
@testable import scrobble

@Suite("UpdateState Tests")
@MainActor
struct UpdateStateTests {

    @Test("Default state has no update available and no error")
    func defaultState() {
        let state = UpdateState()
        #expect(state.updateAvailable == false)
        #expect(state.isChecking == false)
        #expect(state.isDownloading == false)
        #expect(state.errorMessage == nil)
        #expect(state.latestVersion == nil)
        #expect(state.downloadProgress == nil)
    }

    @Test("skipCurrentVersion stores latest and dismisses prompt")
    func skipCurrent() {
        let state = UpdateState()
        state.latestVersion = "v9.9.9"
        state.showUpdatePrompt = true
        state.skipCurrentVersion()
        #expect(state.skippedVersion == "v9.9.9")
        #expect(state.showUpdatePrompt == false)
        // Cleanup so the value doesn't leak into other tests via UserDefaults.
        state.skippedVersion = nil
    }

    @Test("dismissUpdate clears all derived update fields")
    func dismiss() {
        let state = UpdateState()
        state.updateAvailable = true
        state.latestVersion = "v9.9.9"
        state.releaseNotes = "Notes"
        state.latestReleaseURL = URL(string: "https://example.com")
        state.latestPkgURL = URL(string: "https://example.com/x.pkg")
        state.errorMessage = "boom"

        state.dismissUpdate()

        #expect(state.updateAvailable == false)
        #expect(state.latestVersion == nil)
        #expect(state.releaseNotes == nil)
        #expect(state.latestReleaseURL == nil)
        #expect(state.latestPkgURL == nil)
        #expect(state.errorMessage == nil)
    }
}

@Suite("GitHubUpdateClient version comparison")
struct VersionComparisonTests {

    @Test("Newer remote major")
    func newerMajor() {
        #expect(GitHubUpdateClient.isVersion("v2.0.0", newerThan: "1.9.9") == true)
    }

    @Test("Newer remote patch")
    func newerPatch() {
        #expect(GitHubUpdateClient.isVersion("v1.6.10", newerThan: "1.6.9") == true)
    }

    @Test("Equal versions are not newer")
    func equal() {
        #expect(GitHubUpdateClient.isVersion("v1.6.9", newerThan: "1.6.9") == false)
    }

    @Test("Older remote is not newer")
    func older() {
        #expect(GitHubUpdateClient.isVersion("v1.6.0", newerThan: "1.6.9") == false)
    }

    @Test("Strips leading v on both sides")
    func stripsV() {
        #expect(GitHubUpdateClient.isVersion("v1.7.0", newerThan: "v1.6.9") == true)
    }

    @Test("Shorter remote treats missing components as zero")
    func shorterRemote() {
        #expect(GitHubUpdateClient.isVersion("v1.7", newerThan: "1.7.0") == false)
        #expect(GitHubUpdateClient.isVersion("v1.7", newerThan: "1.6.9") == true)
    }
}

@Suite("GitHub model decoding")
struct GitHubDecodingTests {

    @Test("GitHubRelease decodes a realistic payload")
    func releaseDecodes() throws {
        let json = """
        {
            "tag_name": "v1.6.9",
            "name": "v1.6.9",
            "body": "## What's Changed\\n* fix\\n",
            "html_url": "https://github.com/bretth18/scrobble/releases/v1.6.9",
            "prerelease": false,
            "draft": false,
            "assets": [
                {
                    "name": "scrobble.pkg",
                    "browser_download_url": "https://github.com/bretth18/scrobble/releases/download/v1.6.9/scrobble.pkg",
                    "size": 2831701,
                    "content_type": "application/octet-stream"
                }
            ]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: Data(json.utf8))
        #expect(release.tagName == "v1.6.9")
        #expect(release.assets.count == 1)
        #expect(release.assets.first?.name == "scrobble.pkg")
        #expect(release.assets.first?.browserDownloadUrl.hasSuffix(".pkg") == true)
        #expect(release.draft == false)
        #expect(release.prerelease == false)
    }
}
