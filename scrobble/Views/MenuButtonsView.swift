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
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .center) {
                Button {
                    openWindow(id: "scrobbler")
                } label: {
                    Label("Window", systemImage: "rectangle.expand.vertical" )
                        .foregroundStyle(.secondary.opacity(0.7))
                        .font(.caption2)
                }
                .buttonStyle(.glass)
                
                Spacer()
                
//                Button {
//                    openWindow(id: "settings")
//                } label: {
//                    Label("Preferences", systemImage: "gearshape" )
//                        .foregroundStyle(.secondary.opacity(0.7))
//                        .font(.caption2)
//
//                }
//                .buttonStyle(.glass)
//                .foregroundStyle(.tertiary)
                
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "xmark.circle" )
                        .foregroundStyle(.secondary.opacity(0.7))
                        .font(.caption2)
                    
                }
                .buttonStyle(.glass)
                .foregroundStyle(.tertiary)
                
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    MenuButtonsView()
}
