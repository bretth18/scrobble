//
//  NetworkMonitor.swift
//  scrobble
//
//  Observable wrapper around NWPathMonitor. A single instance lives for the
//  lifetime of the app; views read `isConnected` from the environment and
//  react to transitions (e.g. auto-refresh when connectivity returns).
//

import Foundation
import Network
import Observation

@Observable
@MainActor
final class NetworkMonitor {
    /// True when the system reports a satisfied network path.
    /// Defaults to `true` so first-launch UI is not gated on the monitor's first callback.
    private(set) var isConnected: Bool = true

    /// True for paths the system flags as expensive (cellular, hotspot).
    private(set) var isExpensive: Bool = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.scrobble.networkmonitor", qos: .utility)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let expensive = path.isExpensive
            Task { @MainActor in
                self?.apply(isConnected: connected, isExpensive: expensive)
            }
        }
        monitor.start(queue: queue)
    }

    private func apply(isConnected: Bool, isExpensive: Bool) {
        if self.isConnected != isConnected {
            Log.info("NetworkMonitor: connectivity → \(isConnected ? "online" : "offline")", category: .general)
        }
        self.isConnected = isConnected
        self.isExpensive = isExpensive
    }
}
