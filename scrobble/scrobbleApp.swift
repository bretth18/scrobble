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
    @StateObject private var authState = AuthState.shared
    
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
    
    var body: some Scene {
        MenuBarExtra {
            MainView()
                .environmentObject(scrobbler)
                .environmentObject(preferencesManager)
                .sheet(isPresented: $authState.showingAuthSheet) {
                    if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                        LastFmAuthSheet(lastFmManager: desktopManager)
                    }
                }
            
            Divider()
            
            MenuButtons()
                .environmentObject(authState)
                .environmentObject(appState)
        } label: {
            Image(systemName: "music.note")
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Scrobbler") {
            MainView()
                .environmentObject(scrobbler)
                .environmentObject(preferencesManager)
                .environmentObject(appState)
                .environmentObject(authState)
        }
        .defaultPosition(.center)
        .defaultSize(width: 400, height: 600)

        Settings {
            PreferencesView()
                .environmentObject(preferencesManager)
                .environmentObject(scrobbler)
                .environmentObject(authState)
        }
    }
}

struct MenuButtons: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack {
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
        .padding(.horizontal)
    }
}
