//
//  WindowManager.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import SwiftUI

class WindowManager: ObservableObject {
    @Published var isMainWindowShown = false
    @Published var isPreferencesWindowShown = false
    @Published var isAuthWindowShown = false
    
    static let shared = WindowManager()
    private init() {}
    
    func showMainWindow() {
        isMainWindowShown = true
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func showPreferences() {
        isPreferencesWindowShown = true
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func showAuthWindow() {
        isAuthWindowShown = true
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
