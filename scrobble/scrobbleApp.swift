//
//  scrobbleApp.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI

@main
struct scrobbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            VStack(spacing: 10) {
                MainView()
                    .environmentObject(scrobbler)
                    .environmentObject(preferencesManager)
                    .environmentObject(authState)
                
                Divider()
                
                MenuButtons()
                    .environmentObject(authState)
                    .environmentObject(appState)
            }
            .padding(8)
            
        } label: {
            Image(systemName: "music.note")
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Scrobbler", id: "scrobbler") {
            MainView()
                .environmentObject(scrobbler)
                .environmentObject(preferencesManager)
                .environmentObject(appState)
                .environmentObject(authState)
                .sheet(isPresented: $authState.showingAuthSheet) {
                    if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                        LastFmAuthSheet(lastFmManager: desktopManager)
                            .environmentObject(authState)
                    }
                }
        }
        .defaultPosition(.center)
        .defaultSize(width: 400, height: 600)

        
        Settings {
                PreferencesView()
                    .environmentObject(preferencesManager)
                    .environmentObject(scrobbler)
                    .environmentObject(authState)
                    .sheet(isPresented: $authState.showingAuthSheet) {
                        if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                            LastFmAuthSheet(lastFmManager: desktopManager)
                                .environmentObject(authState)
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

struct MenuButtons: View {
    @EnvironmentObject var appState: AppState
    
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(alignment: .center) {
                Button {
                    openWindow(id: "scrobbler")
                } label: {
                    Label("Window", systemImage: "rectangle.expand.vertical" )
                        .foregroundStyle(.secondary.opacity(0.7))
                        .font(.caption2)
                }
                .buttonStyle(.glass)
                
                Spacer()
                
//                Button {
//                    openWindow(id: "settings")
//                } label: {
//                    Label("Preferences", systemImage: "gearshape" )
//                        .foregroundStyle(.secondary.opacity(0.7))
//                        .font(.caption2)
//                    
//                }
//                .buttonStyle(.glass)
//                .foregroundStyle(.tertiary)
                
                
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "xmark.circle" )
                        .foregroundStyle(.secondary.opacity(0.7))
                        .font(.caption2)
                    
                }
                .buttonStyle(.glass)
                .foregroundStyle(.tertiary)
                
            }
            .padding(.horizontal)
        }
    }
}
