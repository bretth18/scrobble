//
//  AppSelectionButton.swift
//  scrobble
//

import SwiftUI

struct AppSelectionButton: View {
    let app: SupportedMusicApp
    let isSelected: Bool
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignTokens.spacingDefault) {
                ZStack {
                    Image(systemName: app.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .secondary)

                    if isRunning {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 12, y: -12)
                            .accessibilityHidden(true)
                    }
                }

                Text(app.displayName)
                    .font(.caption)
                    .bold()
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingSection)
            .padding(.horizontal, DesignTokens.spacingDefault)
        }
        .compatGlassButtonStyle(selected: isSelected)
        .accessibilityLabel("\(app.displayName)\(isRunning ? ", running" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
