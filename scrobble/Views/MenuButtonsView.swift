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
    @Environment(\.openSettings) var openSettings

    var body: some View {
        CompatGlassContainer(spacing: DesignTokens.spacingDefault) {
            buttonsContent
        }
    }

    private var buttonsContent: some View {
        HStack(spacing: DesignTokens.spacingTight) {
            Button {
                openWindow(id: "scrobbler")
                // As an accessory app, windows open behind the frontmost app
                // unless we activate.
                NSApp.activate()
            } label: {
                Label("Window", systemImage: "rectangle.expand.vertical")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .compatGlassButtonStyle()
            .accessibilityLabel("Open window")

            Spacer()

            Button {
                openSettings()
                NSApp.activate()
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }
            .compatGlassButtonStyle()
            .accessibilityLabel("Open settings")

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
