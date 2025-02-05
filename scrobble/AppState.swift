//
//  AppState.swift
//  scrobble
//
//  Created by Brett Henderson on 2/4/25.
//

import Foundation
import SwiftUI
import Combine


class AppState: ObservableObject {
    static let shared = AppState()
    
    @Published var isMainWindowVisible = false {
        didSet { updateMainWindow() }
    }
    @Published var isPreferencesVisible = false {
        didSet { updatePreferencesWindow() }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var mainWindowDelegate: WindowDelegate?
    private var preferencesWindowDelegate: WindowDelegate?
    
    private init() {
        setupWindowDelegates()
        restoreWindowState()
        
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.saveWindowState()
            }
            .store(in: &cancellables)
    }
    
    private func setupWindowDelegates() {
        mainWindowDelegate = WindowDelegate { [weak self] in
            self?.isMainWindowVisible = false
        }
        
        preferencesWindowDelegate = WindowDelegate { [weak self] in
            self?.isPreferencesVisible = false
        }
    }
    
    private func restoreWindowState() {
        isMainWindowVisible = UserDefaults.standard.bool(forKey: "mainWindowVisible")
        isPreferencesVisible = UserDefaults.standard.bool(forKey: "preferencesVisible")
    }
    
    private func saveWindowState() {
        UserDefaults.standard.set(isMainWindowVisible, forKey: "mainWindowVisible")
        UserDefaults.standard.set(isPreferencesVisible, forKey: "preferencesVisible")
    }
    
    func showMainWindow() {
        isMainWindowVisible = true
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func showPreferences() {
        isPreferencesVisible = true
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    private func updateMainWindow() {
        if let window = NSApp.windows.first(where: { $0.title == "Scrobbler" }) {
            if isMainWindowVisible {
                window.delegate = mainWindowDelegate
                window.makeKeyAndOrderFront(nil)
            } else {
                window.close()
            }
        }
    }
    
    private func updatePreferencesWindow() {
        if let window = NSApp.windows.first(where: { $0.title == "Preferences" }) {
            if isPreferencesVisible {
                window.delegate = preferencesWindowDelegate
                window.makeKeyAndOrderFront(nil)
            } else {
                window.close()
            }
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
