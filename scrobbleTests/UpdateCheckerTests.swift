import Testing
@testable import scrobble

@Suite("UpdateChecker Tests")
@MainActor
struct UpdateCheckerTests {

    @Test("No update available when version info is nil")
    func nilVersionNoUpdate() {
        let checker = UpdateChecker()
        #expect(checker.updateAvailable == false)
    }

    @Test("Update available when latest version is higher")
    func higherVersionAvailable() {
        let checker = UpdateChecker()
        checker.latestVersion = "99.0"
        checker.latestBuildNumber = "1"
        #expect(checker.updateAvailable == true)
    }

    @Test("Update available when same version but higher build")
    func higherBuildAvailable() {
        let checker = UpdateChecker()
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        checker.latestVersion = currentVersion
        checker.latestBuildNumber = "9999"
        #expect(checker.updateAvailable == true)
    }

    @Test("No update when version is lower")
    func lowerVersionNoUpdate() {
        let checker = UpdateChecker()
        checker.latestVersion = "0.1"
        checker.latestBuildNumber = "99"
        #expect(checker.updateAvailable == false)
    }

    @Test("No update when same version and same build")
    func sameVersionSameBuild() {
        let checker = UpdateChecker()
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        checker.latestVersion = currentVersion
        checker.latestBuildNumber = currentBuild
        #expect(checker.updateAvailable == false)
    }

    @Test("isChecking defaults to false")
    func isCheckingDefault() {
        let checker = UpdateChecker()
        #expect(checker.isChecking == false)
    }

    @Test("error defaults to nil")
    func errorDefault() {
        let checker = UpdateChecker()
        #expect(checker.error == nil)
    }

    @Test("GitHubRelease decodes correctly")
    func githubReleaseDecode() throws {
        let json = """
        {"tag_name": "v1.6.7", "html_url": "https://github.com/test/test/releases/v1.6.7"}
        """
        let data = json.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        #expect(release.tagName == "v1.6.7")
        #expect(release.htmlURL == "https://github.com/test/test/releases/v1.6.7")
    }
}
