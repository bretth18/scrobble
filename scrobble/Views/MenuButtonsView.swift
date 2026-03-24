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
        CompatGlassContainer(spacing: DesignTokens.spacingDefault) {
            buttonsContent
        }
    }

    private var buttonsContent: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Button {
                openWindow(id: "scrobbler")
            } label: {
                Label("Window", systemImage: "rectangle.expand.vertical")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .compatGlassButtonStyle()
            .accessibilityLabel("Open window")

            Spacer()

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .compatGlassButtonStyle()

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "xmark.circle")
                    .foregroundStyle(.quaternary)
                    .font(.caption)
            }
            .compatGlassButtonStyle()
            .accessibilityLabel("Quit Scrobble")
        }
        .padding(.horizontal)
    }
}

#Preview {
    MenuButtonsView()
        .environment(AppState())
}
