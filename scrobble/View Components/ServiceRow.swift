//
//  ServiceRow.swift
//  scrobble
//

import SwiftUI

struct ServiceRow<Content: View>: View {
    let title: String
    @Binding var isEnabled: Bool
    let status: ServiceStatus
    @ViewBuilder let detailContent: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(.primary)
                Toggle(title, isOn: $isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .accessibilityLabel("Enable \(title)")

                Spacer()

                Label(status.label, systemImage: status.icon)
                    .foregroundStyle(status.color)
                    .font(.caption)
                    .accessibilityLabel("\(title) status: \(status.label)")
            }

            if isEnabled {
                detailContent
                    .padding(.leading)
            }
        }
    }
}
