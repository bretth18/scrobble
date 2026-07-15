//
//  GitHubRelease.swift
//  scrobble
//

import Foundation

/// Decoded with `.convertFromSnakeCase` — see GitHubUpdateClient.
nonisolated struct GitHubRelease: Codable, Sendable {
    let tagName: String
    let name: String
    let body: String?
    let htmlUrl: String
    let assets: [GitHubAsset]
    let prerelease: Bool
    let draft: Bool
}
