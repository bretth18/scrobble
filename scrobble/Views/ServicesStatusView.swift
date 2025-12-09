//
//  ServicesStatusView.swift
//  scrobble
//
//  Created by Brett Henderson on 12/8/25.
//

import SwiftUI

struct ServicesStatusView: View {
    @Environment(Scrobbler.self) var scrobbler
    let refreshTrigger: UUID
    
    var body: some View {
        // The refreshTrigger will force this view to rebuild when ContentView updates it
        let services = scrobbler.getScrobblingServices()
        
        let _ = Log.debug("ServicesStatusView updating with trigger \(refreshTrigger), found \(services.count) services", category: .ui)
        let _ = services.forEach { service in
            Log.debug("  - \(service.serviceName): authenticated = \(service.isAuthenticated)", category: .ui)
        }
        
        if services.isEmpty {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("no services enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        } else {
            ForEach(services, id: \.serviceId) { service in
                HStack(spacing: 6) {
                    Image(systemName: service.isAuthenticated ? "checkmark.circle.fill" : "circle.fill")
                        .foregroundStyle(service.isAuthenticated ? .green.opacity(0.8) : .secondary.opacity(0.5))
                        .font(.caption)
                    
                    Text(service.serviceName.lowercased())
                        .font(.caption)
                        .foregroundStyle(service.isAuthenticated ? .primary : .secondary)
                    
                    Spacer()
                    
                    if !service.isAuthenticated {
                        Text("not authenticated")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.7))
                    }
                }
            }
        }
    }
}

//#Preview {
//    ServicesStatusView(re)
//}
