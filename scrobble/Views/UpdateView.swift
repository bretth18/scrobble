//
//  UpdateView.swift
//  scrobble
//
//  Settings section that surfaces update state: current version, manual
//  check, auto-check toggle, and an inline update card.
//

import SwiftUI
import AppKit

struct UpdateSettingsView: View {
    @Bindable var updateState: UpdateState

    init(updateState: UpdateState) {
        self.updateState = updateState
    }

    var body: some View {
        Section {
            HStack {
                Text("Current Version")
                Spacer()
                Text(updateState.currentFullVersion)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Check for Updates")
                Spacer()
                if updateState.isChecking {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Check Now") {
                        Task { await updateState.checkForUpdate() }
                    }
                    .controlSize(.small)
                }
            }

            Toggle("Check automatically on launch", isOn: Binding(
                get: { updateState.autoCheckEnabled },
                set: { updateState.autoCheckEnabled = $0 }
            ))

            if let lastCheck = updateState.lastCheckDate {
                HStack {
                    Text("Last Checked")
                    Spacer()
                    Text(lastCheck, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if let error = updateState.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if updateState.updateAvailable {
                updateAvailableCard
            } else if !updateState.isChecking, updateState.lastCheckDate != nil, updateState.errorMessage == nil {
                Label("You're running the latest version", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Updates")
        }
    }

    @ViewBuilder
    private var updateAvailableCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingDefault) {
            HStack {
                Text("Version \(updateState.latestVersion ?? "")")
                    .font(.headline)
                Spacer()
                if let url = updateState.latestReleaseURL {
                    Link("View on GitHub", destination: url)
                        .font(.caption)
                }
            }

            if let notes = updateState.releaseNotes, !notes.isEmpty {
                ScrollView {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 150)
            }

            Divider()

            if updateState.isDownloading {
                VStack(alignment: .leading, spacing: DesignTokens.spacingTight) {
                    ProgressView(value: updateState.downloadProgress ?? 0)
                    Text("Downloading… \(Int((updateState.downloadProgress ?? 0) * 100))%")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                HStack {
                    Button("Download & Install") {
                        Task {
                            guard let pkgURL = await updateState.downloadPkg() else { return }
                            NSWorkspace.shared.open(pkgURL)
                        }
                    }
                    .controlSize(.small)
                    .disabled(updateState.latestPkgURL == nil)

                    Spacer()

                    Button("Dismiss") {
                        updateState.dismissUpdate()
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(DesignTokens.cardPadding)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                .fill(Color.accentColor.opacity(0.08))
        }
    }
}

#Preview {
    Form {
        UpdateSettingsView(updateState: UpdateState())
    }
    .formStyle(.grouped)
    .padding()
}
