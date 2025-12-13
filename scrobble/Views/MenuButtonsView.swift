//
//  MenuButtonsView.swift
//  scrobble
//
//  Created by Brett Henderson on 12/8/25.
//

import SwiftUI

struct MenuButtonsView: View {
    @Environment(AppState.self) var appState
    
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 10) {
                buttonsContent
            }
        } else {
            buttonsContent
                .padding(10)
        }
    }

    private var buttonsContent: some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                openWindow(id: "scrobbler")
            } label: {
                Label("Window", systemImage: "rectangle.expand.vertical" )
                    .foregroundStyle(.secondary.opacity(0.5))
                    .font(.caption2)
            }
            .compatGlassButtonStyle()
            
            Spacer()
            
            SettingsLink {
                Label("Settings", systemImage: "gearshape" )
                    .foregroundStyle(.secondary.opacity(0.5))
                    .font(.caption2)
            }
            .compatGlassButtonStyle()

            
            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle" )
                    .foregroundStyle(.secondary.opacity(0.5))
                    .font(.caption2)

            }
            .compatGlassButtonStyle()
            .foregroundStyle(.tertiary)

        }
        .padding(.horizontal)
    }
}

#Preview {
    MenuButtonsView()
}
