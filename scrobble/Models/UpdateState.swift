//
//  UpdateState.swift
//  scrobble
//
//  Observable state for the in-app update flow. Wraps GitHubUpdateClient,
//  publishes UI-driving properties, and persists user preferences (auto-check,
//  skipped version) via UserDefaults.
//

import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class UpdateState {
    private let updateClient = GitHubUpdateClient()

    // Live state
    var isChecking: Bool = false
    var isDownloading: Bool = false
    var updateAvailable: Bool = false
    var latestVersion: String?
    var latestReleaseURL: URL?
    var latestPkgURL: URL?
    var releaseNotes: String?
    var lastCheckDate: Date?
    var errorMessage: String?
    var downloadProgress: Double?

    /// Drives the dedicated "Update Available" window. Kept separate from
    /// `updateAvailable` so settings can show update info without auto-popping
    /// the prompt, and so "Skip this version" suppresses future prompts only.
    var showUpdatePrompt: Bool = false

    private let lastCheckKey = "updateLastCheckDate"
    private let skippedVersionKey = "updateSkippedVersion"

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var currentBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    var currentFullVersion: String {
        "\(currentVersion) (\(currentBuild))"
    }

    /// "1.6.9" form, used when comparing against GitHub tag names.
    var currentFullVersionFormatted: String {
        "\(currentVersion).\(currentBuild)"
    }

    // Persisted preferences use the DefaultsBacked + access/withMutation
    // pattern from PreferencesManager — @Observable only instruments stored
    // properties, so plain computed properties would emit no change events
    // and Settings toggles would render stale.
    @ObservationIgnored @DefaultsBacked("updateAutoCheckEnabled")
    private var _autoCheckEnabled: Bool = true
    var autoCheckEnabled: Bool {
        get {
            access(keyPath: \.autoCheckEnabled)
            return _autoCheckEnabled
        }
        set {
            withMutation(keyPath: \.autoCheckEnabled) {
                _autoCheckEnabled = newValue
            }
        }
    }

    var skippedVersion: String? {
        get {
            access(keyPath: \.skippedVersion)
            return UserDefaults.standard.string(forKey: skippedVersionKey)
        }
        set {
            withMutation(keyPath: \.skippedVersion) {
                if let newValue {
                    UserDefaults.standard.set(newValue, forKey: skippedVersionKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: skippedVersionKey)
                }
            }
        }
    }

    init() {
        let stored = UserDefaults.standard.double(forKey: lastCheckKey)
        if stored > 0 {
            lastCheckDate = Date(timeIntervalSince1970: stored)
        }
    }

    func checkForUpdate() async {
        isChecking = true
        errorMessage = nil

        defer { isChecking = false }

        do {
            let currentFull = currentFullVersionFormatted
            Log.info("Update check: current=\(currentFull) skipped=\(skippedVersion ?? "<none>")", category: .general)
            let result = try await updateClient.fetchLatestRelease(currentVersion: currentFull)

            // Only a successful check counts as "checked" — the menu shows
            // "Up to Date" based on this, so a thrown fetch must not stamp it.
            lastCheckDate = Date()
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)

            updateAvailable = result.isNewer
            latestVersion = result.release.tagName
            releaseNotes = result.release.body

            if let htmlUrl = URL(string: result.release.htmlUrl) {
                latestReleaseURL = htmlUrl
            }

            if let pkg = result.pkgAsset, let url = URL(string: pkg.browserDownloadUrl) {
                latestPkgURL = url
            }

            Log.info("Update check: latest=\(result.release.tagName) isNewer=\(result.isNewer) pkg=\(result.pkgAsset?.browserDownloadUrl ?? "<none>")", category: .general)

            if !result.isNewer {
                Log.info("App is up to date", category: .general)
            } else if latestVersion == skippedVersion {
                Log.info("Update \(latestVersion ?? "?") available but user skipped it", category: .general)
            } else {
                Log.info("Update available — opening prompt window", category: .general)
                showUpdatePrompt = true
            }
        } catch {
            Log.error("Update check failed: \(error.localizedDescription)", category: .general)
            errorMessage = error.localizedDescription
        }
    }

    /// Downloads the .pkg and returns the local URL on success, or nil on failure.
    /// The caller must close the prompt window *before* opening the pkg — see
    /// UpdatePromptSheet for why (Installer force-quits the app and macOS
    /// window restoration would otherwise re-open the prompt indefinitely).
    func downloadPkg() async -> URL? {
        guard let pkgAsset = latestPkgURL, let version = latestVersion else { return nil }

        isDownloading = true
        downloadProgress = 0
        errorMessage = nil

        defer {
            isDownloading = false
            downloadProgress = nil
        }

        do {
            return try await updateClient.downloadPkg(
                from: pkgAsset.absoluteString,
                version: version,
                onProgress: { @Sendable [weak self] progress in
                    Task { @MainActor [weak self] in
                        self?.downloadProgress = progress
                    }
                }
            )
        } catch {
            Log.error("Download failed: \(error.localizedDescription)", category: .general)
            errorMessage = error.localizedDescription
            return nil
        }
    }

    /// Shared download-then-install flow. `beforeInstall` runs between the
    /// completed download and handing the pkg to Installer.app — callers close
    /// their windows there (load-bearing: Installer force-quits the app, and
    /// any window still visible at that point risks being restored on next
    /// launch and looping the prompt).
    func downloadAndInstall(beforeInstall: () -> Void) async {
        guard let pkgURL = await downloadPkg() else { return }
        beforeInstall()
        NSWorkspace.shared.open(pkgURL)
    }

    func skipCurrentVersion() {
        skippedVersion = latestVersion
        showUpdatePrompt = false
    }

    func remindLater() {
        showUpdatePrompt = false
    }

    func dismissUpdate() {
        updateAvailable = false
        latestVersion = nil
        releaseNotes = nil
        latestReleaseURL = nil
        latestPkgURL = nil
        errorMessage = nil
    }

    func checkOnLaunch() {
        guard autoCheckEnabled else { return }
        Task { await checkForUpdate() }
    }
}
