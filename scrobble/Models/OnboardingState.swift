//
//  OnboardingState.swift
//  scrobble
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

@Observable
@MainActor
class OnboardingState {
    enum Step: Int, CaseIterable {
        case welcome
        case authenticate
        case selectApp
        case preferences

        var title: String {
            switch self {
            case .welcome: return "Welcome"
            case .authenticate: return "Connect Last.fm"
            case .selectApp: return "Select App"
            case .preferences: return "Preferences"
            }
        }

        var isFirst: Bool { self == .welcome }
        var isLast: Bool { self == .preferences }
    }

    var currentStep: Step = .welcome
    var isGoingForward: Bool = true

    func canProceed(authState: AuthState) -> Bool {
        switch currentStep {
        case .welcome:
            return true
        case .authenticate:
            return authState.isAuthenticated
        case .selectApp:
            return true
        case .preferences:
            return true
        }
    }

    func next() {
        guard let currentIndex = Step.allCases.firstIndex(of: currentStep),
              currentIndex < Step.allCases.count - 1 else { return }
        isGoingForward = true
        currentStep = Step.allCases[currentIndex + 1]
    }

    func back() {
        guard let currentIndex = Step.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else { return }
        isGoingForward = false
        currentStep = Step.allCases[currentIndex - 1]
    }

    func complete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    static var needsOnboarding: Bool {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        let hasSession = KeychainHelper.load(key: "lastfm_session_key") != nil
            || UserDefaults.standard.string(forKey: "lastfm_session_key") != nil
        return !completed && !hasSession
    }
}
