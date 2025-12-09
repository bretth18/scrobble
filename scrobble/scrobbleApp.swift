//
//  scrobbleApp.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI
import Combine
import Observation

@main
struct scrobbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var preferencesManager = PreferencesManager()
    @State private var scrobbler: Scrobbler
    @State private var appState = AppState()
    @State private var authState: AuthState
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        let prefManager = PreferencesManager()
        _preferencesManager = State(initialValue: prefManager)
        
        let auth = AuthState()
        _authState = State(initialValue: auth)
        
        let lastFmManager = LastFmDesktopManager(
            apiKey: prefManager.apiKey,
            apiSecret: prefManager.apiSecret,
            username: prefManager.username,
            authState: auth
        )
        // Scrobbler is now @Observable so we initialize it as State
        _scrobbler = State(initialValue: Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        
        // Monitor preferences changes to refresh scrobbling services
        setupPreferencesObserver()
    }
    
    private func setupPreferencesObserver() {
        // This will be set up after the StateObjects are initialized
        DispatchQueue.main.async {
            // Note: We can't store this in the struct since it's not mutable
            // The scrobbler will handle its own refresh logic
            Log.debug("Preferences observer setup completed", category: .general)
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: 10) {
            ContentView()
                    .environment(scrobbler)
                    .environment(preferencesManager)
                    .environment(authState)
                
                Divider()
                
                MenuButtonsView()
                    .environment(authState)
                    .environment(appState)
            }
            .padding(8)
            
        } label: {
            Image(systemName: "music.note")
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Scrobbler", id: "scrobbler") {
            ContentView()
                .environment(scrobbler)
                .environment(preferencesManager)
                .environment(appState)
                .environment(authState)
                .sheet(isPresented: $authState.showingAuthSheet) {
                    if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                            LastFMAuthSheetView(lastFmManager: desktopManager)
                            .environment(authState)
                    }
                }
        }
        .defaultPosition(.center)
        .defaultSize(width: 400, height: 600)

        
        Settings {
                PreferencesView()
                    .environment(preferencesManager)
                    .environment(scrobbler)
                    .environment(authState)
                    .sheet(isPresented: $authState.showingAuthSheet) {
                        if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                            LastFMAuthSheetView(lastFmManager: desktopManager)
                                .environment(authState)
                        }
                    }
            
                
        }
        .windowResizability(.automatic)
        .defaultSize(width: 800, height: 600)
    
        
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        
        // Setup URL event handling for Last.fm authentication callbacks
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }
    
    
    @objc func handleURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent replyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
        guard let url = URL(string: urlString) else { return }
        
        // Handle the URL - look for Last.fm auth callbacks
        handleLastFmAuthCallback(url: url)
    }
    
    private func handleLastFmAuthCallback(url: URL) {
        // Example URL: scrobble://auth?token=abc123
        guard url.scheme == "scrobble" else { return }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else { return }
        
        // Check for token parameter
        if let tokenItem = queryItems.first(where: { $0.name == "token" }),
           let token = tokenItem.value {
            // Notify LastFmDesktopManager about successful authorization
            NotificationCenter.default.post(
                name: NSNotification.Name("LastFmAuthSuccess"),
                object: nil,
                userInfo: ["token": token]
            )
        }
        // Check for error parameter
        else if let errorItem = queryItems.first(where: { $0.name == "error" }),
                let error = errorItem.value {
            // Notify LastFmDesktopManager about failed authorization
            NotificationCenter.default.post(
                name: NSNotification.Name("LastFmAuthFailure"),
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
}
