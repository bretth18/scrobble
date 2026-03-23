//
//  ServiceStatus.swift
//  scrobble
//

import SwiftUI

enum ServiceStatus {
    case connected
    case notConnected
    case failed
    case checking
    case disabled

    var label: String {
        switch self {
        case .connected: "Connected"
        case .notConnected: "Not connected"
        case .failed: "Auth failed"
        case .checking: "Checking..."
        case .disabled: "Disabled"
        }
    }

    var icon: String {
        switch self {
        case .connected: "checkmark.seal.fill"
        case .notConnected: "exclamationmark.triangle.fill"
        case .failed: "xmark.octagon.fill"
        case .checking: "hourglass"
        case .disabled: "minus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .connected: .green
        case .notConnected: .yellow
        case .failed: .red
        case .checking: .secondary
        case .disabled: .secondary
        }
    }
}
