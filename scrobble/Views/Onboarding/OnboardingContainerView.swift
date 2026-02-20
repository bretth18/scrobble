//
//  OnboardingContainerView.swift
//  scrobble
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

struct OnboardingContainerView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(PreferencesManager.self) var preferencesManager
    @Environment(Scrobbler.self) var scrobbler
    @Environment(AuthState.self) var authState
    @State private var onboardingState = OnboardingState()

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingState.Step.allCases, id: \.self) { step in
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: onboardingState.currentStep)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 8)

            // Step title
            Text(onboardingState.currentStep.title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            // Content area
            ZStack {
                switch onboardingState.currentStep {
                case .welcome:
                    OnboardingWelcomeView()
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .authenticate:
                    OnboardingAuthView()
                        .environment(scrobbler)
                        .environment(authState)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .selectApp:
                    OnboardingAppSelectionView()
                        .environment(preferencesManager)
                        .environment(scrobbler)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))

                case .preferences:
                    OnboardingPreferencesView()
                        .environment(preferencesManager)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.3), value: onboardingState.currentStep)

            Divider()

            // Navigation buttons
            HStack {
                if !onboardingState.currentStep.isFirst {
                    Button("Back") {
                        onboardingState.back()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if onboardingState.currentStep.isLast {
                    Button("Complete Setup") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Continue") {
                        onboardingState.next()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!onboardingState.canProceed(authState: authState))
                }
            }
            .padding()
        }
        .frame(width: 500, height: 520)
        .background(.ultraThinMaterial)
    }

    private func stepColor(for step: OnboardingState.Step) -> Color {
        if step.rawValue < onboardingState.currentStep.rawValue {
            return .accentColor
        } else if step == onboardingState.currentStep {
            return .accentColor
        } else {
            return .secondary.opacity(0.3)
        }
    }

    private func completeOnboarding() {
        onboardingState.complete()
        dismissWindow(id: "onboarding")
    }
}

#Preview {
    let prefManager = PreferencesManager()
    let authState = AuthState()
    let lastFmManager = LastFmDesktopManager(
        apiKey: prefManager.apiKey,
        apiSecret: prefManager.apiSecret,
        username: prefManager.username,
        authState: authState
    )

    OnboardingContainerView()
        .environment(prefManager)
        .environment(Scrobbler(lastFmManager: lastFmManager, preferencesManager: prefManager))
        .environment(authState)
        .padding(100)

}
