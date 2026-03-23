//
//  ServicesStatusView.swift
//  scrobble
//
//  Created by Brett Henderson on 12/8/25.
//

import SwiftUI

struct ServicesStatusView: View {
    @Environment(Scrobbler.self) var scrobbler

    var body: some View {
        let services = scrobbler.getScrobblingServices()

        if services.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("no services enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Warning: no services enabled")
        } else {
            ForEach(services, id: \.serviceId) { service in
                HStack(spacing: DesignTokens.spacingDefault) {
                    Image(systemName: service.isAuthenticated ? "checkmark.circle.fill" : "circle.fill")
                        .foregroundStyle(service.isAuthenticated ? Color.green : Color.secondary.opacity(0.3))
                        .font(.caption)

                    Text(service.serviceName.lowercased())
                        .font(.caption)
                        .foregroundStyle(service.isAuthenticated ? .primary : .secondary)

                    Spacer()

                    if !service.isAuthenticated {
                        Text("not authenticated")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "\(service.serviceName): \(service.isAuthenticated ? "connected" : "not authenticated")"
                )
            }
        }
    }
}
