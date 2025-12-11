//
//  UpdateChecker.swift
//  scrobble
//
//  Created by Brett Henderson on 12/11/25.
//

import Foundation

@Observable
final class UpdateChecker {
    var latestVersion: String?
    var latestBuildNumber: String?
    var downloadURL: URL?
    var isChecking = false
    var error: Error?
    
    var updateAvailable: Bool {
        guard let latestVersion, let latestBuild = latestBuildNumber else { return false }
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        let currentBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        
        if latestVersion != currentVersion {
            return latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending
        }
        return latestBuild.compare(currentBuild, options: .numeric) == .orderedDescending
    }
    
    var currentVersionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
    }
    
    var latestVersionString: String? {
        guard let latestVersion, let latestBuildNumber else { return nil }
        return "\(latestVersion) (\(latestBuildNumber))"
    }
    
    func checkForUpdates(owner: String, repo: String) async {
        isChecking = true
        error = nil
        defer { isChecking = false }
        
        do {
            let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
            let (data, _) = try await URLSession.shared.data(from: url)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            print(release)
            
            // Parse "v1.6.4" -> version "1.6", build "4"
            let tag = release.tagName.trimmingPrefix("v")
            let components = tag.split(separator: ".")
            
            if components.count >= 3 {
                latestVersion = "\(components[0]).\(components[1])"
                latestBuildNumber = String(components[2])
            } else if components.count == 2 {
                latestVersion = String(tag)
                latestBuildNumber = "0"
            }
            
            downloadURL = URL(string: release.htmlURL)
        } catch {
            self.error = error
        }
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let htmlURL: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
