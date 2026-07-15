//
//  GitHubAsset.swift
//  scrobble
//

import Foundation

/// Decoded with `.convertFromSnakeCase` — see GitHubUpdateClient.
nonisolated struct GitHubAsset: Codable, Sendable {
    let name: String
    let browserDownloadUrl: String
    let size: Int
    let contentType: String
}
