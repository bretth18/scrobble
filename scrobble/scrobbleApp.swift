//
//  scrobbleApp.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

@main
struct scrobbleApp: App {
    @StateObject private var preferencesManager = PreferencesManager()
    @StateObject private var scrobbler: Scrobbler
    @State private var isMainWindowShown = false
    @State private var isPreferencesWindowShown = false
    
    init() {
        let prefManager = PreferencesManager()
        _preferencesManager = StateObject(wrappedValue: prefManager)
        
        let lastFmManager = LastFmDesktopManager(
            apiKey: prefManager.apiKey,
            apiSecret: prefManager.apiSecret,
            username: prefManager.username,
            password: prefManager.password
        )
        _scrobbler = StateObject(wrappedValue: Scrobbler(lastFmManager: lastFmManager))
    }
    
    
    private var authSheetBinding: Binding<Bool> {
        Binding(
            get: {
                (scrobbler.lastFmManager as? LastFmDesktopManager)?.showingAuthSheet ?? false
            },
            set: { newValue in
                if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                    desktopManager.showingAuthSheet = newValue
                }
            }
        )
    }
    
    var body: some Scene {
        Group {
            MenuBarExtra("SCROBBLER", systemImage: "music.note") {
                MainView()
                    .environmentObject(scrobbler)
                    .environmentObject(preferencesManager)
                    .sheet(isPresented: authSheetBinding) {
                        if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                            LastFmAuthSheet(lastFmManager: desktopManager)
                        }
                    }
                
                Divider()
                
                HStack(alignment: .center) {
                    Button("Open window") {
                        isMainWindowShown = true
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                    
                    Button("Open preferences") {
                        isPreferencesWindowShown = true
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                }
                .padding()
            }
            .menuBarExtraStyle(.window)
            
            WindowGroup("Scrobbler") {
                MainView()
                    .environmentObject(scrobbler)
                    .environmentObject(preferencesManager)
                    .sheet(isPresented: authSheetBinding) {
                        if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                            LastFmAuthSheet(lastFmManager: desktopManager)
                        }
                    }
            }
            .commands {
                CommandMenu("Window") {
                    Button("Toggle Main Window") {
                        isMainWindowShown.toggle()
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                    .keyboardShortcut("m", modifiers: [.command, .shift])
                }
                
                CommandMenu("Preferences")
                {
                    Button("Toggle Preferences Window") {
                        isPreferencesWindowShown.toggle()
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
                }
            }
            .defaultSize(width: 400, height: 600)
            
            WindowGroup("Preferences") {
                PreferencesView()
                    .environmentObject(preferencesManager)
            }
            .defaultSize(width: 300, height: 200)
        }
    }
}
