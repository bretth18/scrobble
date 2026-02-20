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
            preferencesManager.launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        .onChange(of: preferencesManager.launchAtLogin) { _, newValue in
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                Log.error("Failed to update launch at login: \(error)", category: .general)
                preferencesManager.launchAtLogin = !newValue
            }
        }
    }
}

#Preview {
    LaunchAtLoginSettingsView()
        .environment(PreferencesManager())
}
