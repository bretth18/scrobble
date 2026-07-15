//
//  scrobbleApp.swift
//  scrobble
//
//  Created by Brett Henderson on 9/6/24.
//

import SwiftUI
import Observation
import Combine

@main
struct scrobbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var preferencesManager: PreferencesManager
    @State private var scrobbler: Scrobbler
    @State private var authState: AuthState
    @State private var updateState = UpdateState()
    @State private var networkMonitor = NetworkMonitor()
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

    private var menuBarIcon: String {
        scrobbler.errorMessage != nil ? "music.note.tv" : "music.note"
    }

    var body: some Scene {
        MenuBarExtra {
            VStack(spacing: DesignTokens.spacingDefault) {
                    ContentView()
                        .environment(scrobbler)
                        .environment(preferencesManager)
                        .environment(authState)
                        .environment(networkMonitor)

                    Divider()

                    MenuButtonsView()
                        .environment(authState)
                }
                .padding(DesignTokens.spacingDefault)
                .containerBackground(
                    .ultraThinMaterial, for: .window
                )
                .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
                .background {
                    OnboardingLauncher(hasCheckedOnboarding: $hasCheckedOnboarding)
                    UpdateLauncher(updateState: updateState)
                    DockReopenLauncher()
                }
        } label: {
            Image(systemName: menuBarIcon)
                .symbolEffect(.pulse, isActive: scrobbler.isScrobbling)
                .accessibilityLabel("Scrobble")
        }
        .menuBarExtraStyle(.window)

        Window("Scrobbler", id: "scrobbler") {
            ContentView()
                .environment(scrobbler)
                .environment(preferencesManager)
                .environment(authState)
                .environment(networkMonitor)
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
        // Menu bar app: the main window should only appear when explicitly
        // opened, never automatically at launch or via restoration (#9).
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        Settings {
            PreferencesView()
                .environment(preferencesManager)
                .environment(scrobbler)
                .environment(authState)
                .environment(updateState)
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
                CheckForUpdatesMenuItem(updateState: updateState)
            }
        }

        // Onboarding window
        Window("Welcome to Scrobble", id: "onboarding") {
            OnboardingContainerView()
                .environment(preferencesManager)
                .environment(scrobbler)
                .environment(authState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        // Only OnboardingLauncher opens this — never the system at launch.
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)

        // Update prompt window — opened by UpdateLauncher when an update is
        // available. Never opens at launch, and restoration is disabled so a
        // stale prompt can't come back after the Installer force-quit path.
        Window("Update Available", id: "update-prompt") {
            UpdatePromptSheet(updateState: updateState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commandsRemoved()
    }

}

// MARK: - Check for Updates Menu Item

/// App-menu update command. Opens the prompt window itself via `openWindow`
/// rather than only flipping `showUpdatePrompt` — the onChange bridge that
/// watches that flag lives in the MenuBarExtra content, which isn't a safe
/// dependency from the main menu.
struct CheckForUpdatesMenuItem: View {
    @Environment(\.openWindow) private var openWindow
    let updateState: UpdateState

    var body: some View {
        Button {
            if updateState.updateAvailable {
                updateState.showUpdatePrompt = true
                openWindow(id: "update-prompt")
                NSApp.activate()
            } else {
                Task { await updateState.checkForUpdate() }
            }
        } label: {
            if updateState.isChecking {
                Label("Checking...", systemImage: "arrow.trianglehead.2.clockwise")
            } else if updateState.updateAvailable {
                Label("Download Update", systemImage: "arrow.down.circle")
            } else if updateState.lastCheckDate != nil {
                Label("Up to Date", systemImage: "checkmark.circle")
            } else {
                Label("Check for Updates...", systemImage: "arrow.clockwise")
            }
        }
        .disabled(updateState.isChecking)
    }
}

// MARK: - Update Launcher

/// Invisible helper that runs the on-launch update check and bridges
/// `UpdateState.showUpdatePrompt` to opening / dismissing the prompt window.
/// Without this bridge, flipping the bool wouldn't move the window.
struct UpdateLauncher: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var hasCheckedOnLaunch = false
    let updateState: UpdateState

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .task {
                // .task on MenuBarExtra content re-fires on every popover
                // open; the launch check must run exactly once or "Remind Me
                // Later" is defeated and every click hits the GitHub API.
                guard !hasCheckedOnLaunch else { return }
                hasCheckedOnLaunch = true

                updateState.checkOnLaunch()
                if updateState.showUpdatePrompt {
                    openWindow(id: "update-prompt")
                }
            }
            .onChange(of: updateState.showUpdatePrompt) { _, show in
                if show {
                    openWindow(id: "update-prompt")
                    NSApp.activate()
                } else {
                    dismissWindow(id: "update-prompt")
                }
            }
    }
}

// MARK: - Dock Reopen Launcher

extension Notification.Name {
    /// Posted by the app delegate when the user clicks the Dock icon (or
    /// relaunches the app) while no windows are visible.
    static let dockReopen = Notification.Name("DockReopen")
}

/// Bridges Dock-icon reopen events to opening the main window. The app
/// delegate can't reach `openWindow`, so it posts a notification instead.
struct DockReopenLauncher: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onReceive(NotificationCenter.default.publisher(for: .dockReopen)) { _ in
                openWindow(id: "scrobbler")
                NSApp.activate()
            }
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
        // LSUIElement launches us as an accessory; promote to .regular if the
        // user has opted into showing the Dock icon.
        PreferencesManager.applyActivationPolicy()

        // Setup URL event handling for Last.fm authentication callbacks
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .dockReopen, object: nil)
        }
        return true
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
