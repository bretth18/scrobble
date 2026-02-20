//
//  ErrorMessageView.swift
//  scrobble
//
//  Created by Brett Henderson on 1/17/25.
//

import SwiftUI

struct ErrorMessageView: View {
    let message: String

    init(_ message: String = "Something went wrong.") {
        self.message = message
    }

    var body: some View {
        VStack {
            Label("Error", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                .fill(Color.red.opacity(0.1))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium)
                        .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview {
    ErrorMessageView("Failed to connect to Last.fm")
}
