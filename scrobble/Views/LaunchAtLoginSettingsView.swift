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
            VStack(alignment: .leading, spacing: 4) {
                Toggle("Launch at Login", isOn: $preferencesManager.launchAtLogin)
                Text("""
                when enabled, scrobble will automatically start when you log in to your computer.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        

        } header: {
            Text("Startup")
        }
        .onAppear {
            if SMAppService.mainApp.status == .enabled {
                preferencesManager.launchAtLogin = true
            } else {
                preferencesManager.launchAtLogin = false
            }
        }
        .onChange(of: preferencesManager.launchAtLogin) { _, newValue in
            if newValue == true {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
            
    }
}

#Preview {
    LaunchAtLoginSettingsView()
        .environment(PreferencesManager())
}
