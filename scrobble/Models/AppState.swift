//
//  AppState.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import SwiftUI
import Combine
import Observation


@Observable
class AppState {
    var isMainWindowVisible = false
    var isPreferencesVisible = false
    
    init() {
        // Restore window state if needed
        isMainWindowVisible = UserDefaults.standard.bool(forKey: "mainWindowVisible")
    }
    
    func showMainWindow() {
        isMainWindowVisible = true
        activateWindow(named: "Scrobbler")
    }
    
    func showPreferences() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
    
    private func activateWindow(named title: String) {
        if let window = NSApp.windows.first(where: { $0.title == title }) {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    
    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        super.init()
    }
    
    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
