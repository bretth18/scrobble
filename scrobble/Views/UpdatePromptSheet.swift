//
//  UpdatePromptSheet.swift
//  scrobble
//
//  Dedicated window shown when an update is available. The window is opened
//  by MainView/scrobbleApp watching `UpdateState.showUpdatePrompt`.
//

import SwiftUI
import AppKit

struct UpdatePromptSheet: View {
    @Bindable var updateState: UpdateState
    @Environment(\.dismissWindow) private var dismissWindow

    private func close() {
        updateState.showUpdatePrompt = false
        dismissWindow(id: "update-prompt")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingLarge) {
            header
            releaseNotes
            Spacer(minLength: 0)
            buttons
        }
        .padding(DesignTokens.spacingLarge)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 380, idealHeight: 480)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignTokens.spacingSection) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: DesignTokens.onboardingIconSize))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                Text("Update Available")
                    .font(.title2)
                    .bold()

                if let latest = updateState.latestVersion {
                    Text("Version \(latest) — you're on \(updateState.currentFullVersionFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var releaseNotes: some View {
        if let notes = updateState.releaseNotes, !notes.isEmpty {
            ScrollView {
                Text(notes)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DesignTokens.spacingSection)
            }
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium, style: .continuous))
        } else {
            Text("No release notes available.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var buttons: some View {
        HStack(spacing: DesignTokens.spacingDefault) {
            Button("Skip This Version") {
                updateState.skipCurrentVersion()
                close()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button("Remind Me Later") {
                updateState.remindLater()
                close()
            }
            .keyboardShortcut(.cancelAction)

            if updateState.isDownloading {
                downloadProgress
            } else {
                Button("Download & Install") {
                    // Sequence is load-bearing: download, then dismiss this
                    // window, *then* hand the pkg to Installer.app. If we
                    // leave the window visible when Installer force-quits us,
                    // macOS restores it on next launch and the prompt loops.
                    Task {
                        guard let pkgURL = await updateState.downloadPkg() else {
                            return
                        }
                        close()
                        NSWorkspace.shared.open(pkgURL)
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(updateState.latestPkgURL == nil)
            }
        }
    }

    private var downloadProgress: some View {
        HStack(spacing: DesignTokens.spacingDefault) {
            ProgressView(value: updateState.downloadProgress ?? 0) {
                Text(progressLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .progressViewStyle(.linear)
            .frame(width: 140)
        }
    }

    private var progressLabel: String {
        if let p = updateState.downloadProgress {
            return "\(Int(p * 100))%"
        }
        return "Starting…"
    }
}

#if DEBUG
@MainActor
private func previewUpdateState(
    latestVersion: String? = "v1.7.0",
    releaseNotes: String? = """
    ## What's New

    - Network changes (e.g. plugging into Ethernet) now auto-recover the Friends view.
    - In-app update flow with progress, skip-version, and one-click install.

    ## Fixes

    - No more stale errors after reconnect.
    """,
    isDownloading: Bool = false,
    progress: Double? = nil,
    hasPkgURL: Bool = true
) -> UpdateState {
    let state = UpdateState()
    state.latestVersion = latestVersion
    state.releaseNotes = releaseNotes
    state.isDownloading = isDownloading
    state.downloadProgress = progress
    if hasPkgURL {
        state.latestPkgURL = URL(string: "https://example.com/scrobble.pkg")
    }
    return state
}

#Preview("Update available") {
    UpdatePromptSheet(updateState: previewUpdateState())
}

#Preview("Downloading — 45%") {
    UpdatePromptSheet(updateState: previewUpdateState(isDownloading: true, progress: 0.45))
}

#Preview("No release notes") {
    UpdatePromptSheet(updateState: previewUpdateState(releaseNotes: nil))
}
#endif
