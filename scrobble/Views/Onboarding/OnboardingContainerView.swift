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
            HStack(spacing: DesignTokens.spacingDefault) {
                ForEach(OnboardingState.Step.allCases, id: \.self) { step in
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: onboardingState.currentStep)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, DesignTokens.spacingDefault)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(onboardingState.currentStep.rawValue + 1) of \(OnboardingState.Step.allCases.count)")

            // Step title
            Text(onboardingState.currentStep.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, DesignTokens.spacingLarge)

            // Content area
            ZStack {
                switch onboardingState.currentStep {
                case .welcome:
                    OnboardingWelcomeView()
                        .transition(stepTransition)

                case .authenticate:
                    OnboardingAuthView()
                        .environment(scrobbler)
                        .environment(authState)
                        .transition(stepTransition)

                case .selectApp:
                    OnboardingAppSelectionView()
                        .environment(preferencesManager)
                        .environment(scrobbler)
                        .transition(stepTransition)

                case .preferences:
                    OnboardingPreferencesView()
                        .environment(preferencesManager)
                        .transition(stepTransition)
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

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: onboardingState.isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: onboardingState.isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    private func stepColor(for step: OnboardingState.Step) -> Color {
        step.rawValue <= onboardingState.currentStep.rawValue
            ? .accentColor
            : .secondary.opacity(0.3)
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
