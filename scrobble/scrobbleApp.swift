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
    @StateObject private var appState = AppState.shared
    
    init() {
        let prefManager = PreferencesManager()
        _preferencesManager = StateObject(wrappedValue: prefManager)
        
        let lastFmManager = LastFmDesktopManager(
            apiKey: prefManager.apiKey,
            apiSecret: prefManager.apiSecret,
            username: prefManager.username
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
        MenuBarExtra {
            VStack(alignment: .center, spacing: 0) {
                MainView()
                    .environmentObject(scrobbler)
                    .environmentObject(preferencesManager)
                    .sheet(isPresented: authSheetBinding) {
                        if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                            LastFmAuthSheet(lastFmManager: desktopManager)
                        }
                    }
                    .padding(.top, 4)
                
                Divider()
                
                HStack(alignment: .center) {
                    Button("Open Window") {
                        appState.showMainWindow()
                    }
                    
                    Button("Preferences") {
                        appState.showPreferences()
                    }
                    
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .padding()
                
            }
        } label: {
            Image(systemName: "music.note")
        }
        .menuBarExtraStyle(.window)

        WindowGroup {
            MainView()
                .environmentObject(scrobbler)
                .environmentObject(preferencesManager)
                .sheet(isPresented: authSheetBinding) {
                    if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                        LastFmAuthSheet(lastFmManager: desktopManager)
                    }
                }
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .defaultSize(width: 400, height: 600)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Window") {
                Button("Toggle Main Window") {
                    appState.isMainWindowVisible.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
        

        Settings {
            PreferencesView()
                .environmentObject(preferencesManager)
                .environmentObject(scrobbler)
                .frame(width: 500, height: 500)
        }
    }
}
