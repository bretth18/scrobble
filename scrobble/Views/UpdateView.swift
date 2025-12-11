//
//  UpdateView.swift
//  scrobble
//
//  Created by Brett Henderson on 12/11/25.
//

import SwiftUI

struct UpdateSettingsView: View {
    @Environment(UpdateChecker.self) var updateChecker
    
    private let owner = "bretth18"
    private let repo = "scrobble"
    
    var body: some View {
        Section {
            HStack(alignment: .center) {
                Text("Current")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(updateChecker.currentVersionString)
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.5))
                
                Spacer()
                
                if updateChecker.isChecking {
                    ProgressView()
                        .controlSize(.small)
                } else if let latest = updateChecker.latestVersionString {
                    if updateChecker.updateAvailable {
                        Text("Update available: \(latest)")
                            .font(.caption)
                            .foregroundColor(.blue)
                    } else {
                        Label("Up to date", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            if let error = updateChecker.error {
                Text(error.localizedDescription)
                    .font(.caption2)
                    .foregroundColor(.red)
            }
            
            HStack {
                Button("Check for Updates") {
                    Task {
                        await updateChecker.checkForUpdates(owner: owner, repo: repo)
                    }
                }
                .disabled(updateChecker.isChecking)
                .controlSize(.small)
                
                if updateChecker.updateAvailable, let url = updateChecker.downloadURL {
                    Link("Download", destination: url)
                        .controlSize(.small)
                }
            }
        } header: {
            Text("Updates")
        }
    }
}

#Preview {
    VStack {
    UpdateSettingsView()
        .environment(UpdateChecker() )
        .padding()
    }
}
