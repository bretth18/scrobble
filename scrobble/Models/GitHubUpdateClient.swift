//
//  GitHubUpdateClient.swift
//  scrobble
//
//  Fetches the latest GitHub release and downloads the .pkg installer to a
//  cache directory. Pure transport — does not touch any UI state.
//

import Foundation

actor GitHubUpdateClient {
    private let session = URLSession.shared
    private let baseURL = "https://api.github.com/repos/bretth18/scrobble/releases/latest"

    struct UpdateResult {
        let release: GitHubRelease
        let pkgAsset: GitHubAsset?
        let isNewer: Bool
    }

    func fetchLatestRelease(currentVersion: String) async throws -> UpdateResult {
        guard let url = URL(string: baseURL) else {
            throw UpdateError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                throw UpdateError.noReleasesFound
            }
            throw UpdateError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let release = try decoder.decode(GitHubRelease.self, from: data)

        guard !release.draft, !release.prerelease else {
            throw UpdateError.noStableRelease
        }

        let pkgAsset = release.assets.first { $0.name.hasSuffix(".pkg") }
        let isNewer = Self.isVersion(release.tagName, newerThan: currentVersion)

        return UpdateResult(release: release, pkgAsset: pkgAsset, isNewer: isNewer)
    }

    func downloadPkg(from urlString: String, version: String, onProgress: @Sendable @escaping (Double) -> Void) async throws -> URL {
        guard let url = URL(string: urlString) else {
            throw UpdateError.invalidURL
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.scrobble"
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("\(bundleID)/updates", isDirectory: true)

        try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        let destination = cacheDir.appendingPathComponent("scrobble-\(version).pkg")

        try? FileManager.default.removeItem(at: destination)

        // A download task streams to disk instead of buffering the pkg in
        // memory; progress comes from KVO on the task's Progress. The temp
        // file is only valid inside the completion handler, so the move to
        // the cache directory happens there.
        var observation: NSKeyValueObservation?
        defer { observation?.invalidate() }

        let downloaded: URL = try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: URLRequest(url: url)) { tempURL, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let tempURL,
                      let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continuation.resume(throwing: UpdateError.downloadFailed)
                    return
                }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destination)
                    continuation.resume(returning: destination)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                onProgress(progress.fractionCompleted)
            }
            task.resume()
        }

        onProgress(1.0)
        return downloaded
    }

    /// Numeric, dot-separated semver comparison. Strips a leading "v".
    static func isVersion(_ remote: String, newerThan local: String) -> Bool {
        let remoteParts = parseVersion(remote)
        let localParts = parseVersion(local)

        let maxCount = max(remoteParts.count, localParts.count)
        for i in 0..<maxCount {
            let r = i < remoteParts.count ? remoteParts[i] : 0
            let l = i < localParts.count ? localParts[i] : 0
            if r > l { return true }
            if r < l { return false }
        }
        return false
    }

    private static func parseVersion(_ version: String) -> [Int] {
        let cleaned = version.hasPrefix("v") ? String(version.dropFirst()) : version
        return cleaned.split(separator: ".").compactMap { Int($0) }
    }
}

enum UpdateError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case noReleasesFound
    case noStableRelease
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .invalidResponse: "Invalid server response"
        case .httpError(let code): "Server returned status \(code)"
        case .noReleasesFound: "No releases found"
        case .noStableRelease: "No stable release available"
        case .downloadFailed: "Download failed"
        }
    }
}
