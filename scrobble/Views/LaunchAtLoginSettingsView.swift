//
//  LaunchAtLoginSettingsView.swift
//  scrobble
//
//  Created by Brett Henderson on 12/12/25.
//

import SwiftUI
import ServiceManagement

struct LaunchAtLoginSettingsView: View {
    @Environment(PreferencesManager.self) var preferencesManager

    /// `.requiresApproval` counts as registered: the item exists in System
    /// Settings and will take effect once approved, so the toggle must show
    /// ON and toggling OFF must actually unregister it.
    private var isRegistered: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: true
        default: false
        }
    }

    var body: some View {
        @Bindable var preferencesManager = preferencesManager

        Section {
            Toggle("Launch at Login", isOn: $preferencesManager.launchAtLogin)
        } header: {
            Text("Startup")
        } footer: {
            Text("When enabled, Scrobble will automatically start when you log in to your computer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            preferencesManager.launchAtLogin = isRegistered
        }
        .onChange(of: preferencesManager.launchAtLogin) { _, newValue in
            // The onAppear sync above also lands here; skip when the toggle
            // already matches the registered state so we don't re-register
            // (or ping-pong on repeated failures).
            guard newValue != isRegistered else { return }

            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.error("Failed to update launch at login: \(error)", category: .general)
                preferencesManager.launchAtLogin = isRegistered
            }
        }
    }
}

#Preview {
    LaunchAtLoginSettingsView()
        .environment(PreferencesManager())
}
