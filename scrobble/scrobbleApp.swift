//
//  scrobbleApp.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI
import Observation

@main
struct scrobbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var preferencesManager = PreferencesManager()
    @State private var scrobbler: Scrobbler
    @State private var appState = AppState()
    @State private var authState: AuthState
    @State private var updateChecker = UpdateChecker()
    @State private var hasCheckedOnboarding = false

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
        _scrobbler = State(initialValue: Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: DesignTokens.spacingDefault) {
                ContentView()
                    .environment(scrobbler)
                    .environment(preferencesManager)
                    .environment(authState)

                Divider()

                MenuButtonsView()
                    .environment(authState)
                    .environment(appState)
            }
            .padding(DesignTokens.spacingDefault)
            .containerBackground(
                .ultraThinMaterial, for: .window
            )
            .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
            .background {
                OnboardingLauncher(hasCheckedOnboarding: $hasCheckedOnboarding)
            }
        } label: {
            Image(systemName: "music.note")
                .accessibilityLabel("Scrobble")
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
                .containerBackground(
                    .ultraThinMaterial, for: .window
                )
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        }
        .defaultPosition(.center)
        .defaultSize(width: 400, height: 600)

        Settings {
            PreferencesView()
                .environment(preferencesManager)
                .environment(scrobbler)
                .environment(authState)
                .environment(updateChecker)
                .sheet(isPresented: $authState.showingAuthSheet) {
                    if let desktopManager = scrobbler.lastFmManager as? LastFmDesktopManager {
                        LastFMAuthSheetView(lastFmManager: desktopManager)
                            .environment(authState)
                    }
                }
        }
        .windowResizability(.automatic)
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .appInfo) {
                Button {
                    if updateChecker.updateAvailable, let url = updateChecker.downloadURL {
                        NSWorkspace.shared.open(url)
                    } else {
                        Task {
                            await updateChecker.checkForUpdates(owner: "bretth18", repo: "scrobble")
                        }
                    }
                } label: {
                    if updateChecker.isChecking {
                        Label("Checking...", systemImage: "arrow.trianglehead.2.clockwise")
                    } else if updateChecker.updateAvailable {
                        Label("Download Update", systemImage: "arrow.down.circle")
                    } else if updateChecker.latestVersion != nil {
                        Label("Up to Date", systemImage: "checkmark.circle")
                    } else {
                        Label("Check for Updates...", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(updateChecker.isChecking)
            }
        }

        // Onboarding window
        WindowGroup("Welcome to Scrobble", id: "onboarding") {
            OnboardingContainerView()
                .environment(preferencesManager)
                .environment(scrobbler)
                .environment(authState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

}

// MARK: - Onboarding Launcher

/// Helper view that checks if onboarding should be shown and opens the window.
/// Uses .task instead of .onAppear for structured concurrency.
struct OnboardingLauncher: View {
    @Environment(\.openWindow) private var openWindow
    @Binding var hasCheckedOnboarding: Bool

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                guard !hasCheckedOnboarding else { return }
                hasCheckedOnboarding = true

                if OnboardingState.needsOnboarding {
                    try? await Task.sleep(for: .milliseconds(500))
                    openWindow(id: "onboarding")
                    NSApp.activate()
                }
            }
    }
}

@MainActor
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

        handleLastFmAuthCallback(url: url)
    }

    private func handleLastFmAuthCallback(url: URL) {
        guard url.scheme == "scrobble" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let queryItems = components?.queryItems else { return }

        if let tokenItem = queryItems.first(where: { $0.name == "token" }),
           let token = tokenItem.value {
            NotificationCenter.default.post(
                name: NSNotification.Name("LastFmAuthSuccess"),
                object: nil,
                userInfo: ["token": token]
            )
        } else if let errorItem = queryItems.first(where: { $0.name == "error" }),
                  let error = errorItem.value {
            NotificationCenter.default.post(
                name: NSNotification.Name("LastFmAuthFailure"),
                object: nil,
                userInfo: ["error": error]
            )
        }
    }
}
