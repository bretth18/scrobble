//
//  OnboardingContainerView.swift
//  scrobble
//
//  Created by Claude on 1/12/26.
//

import SwiftUI

struct OnboardingContainerView: View {
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PreferencesManager.self) var preferencesManager
    @Environment(Scrobbler.self) var scrobbler
    @Environment(AuthState.self) var authState
    @State private var onboardingState = OnboardingState()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.spacingDefault) {
                ForEach(OnboardingState.Step.allCases, id: \.self) { step in
                    Circle()
                        .fill(stepColor(for: step))
                        .frame(width: 8, height: 8)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: onboardingState.currentStep)
            .padding(.top, 20)
            .padding(.bottom, DesignTokens.spacingDefault)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(onboardingState.currentStep.rawValue + 1) of \(OnboardingState.Step.allCases.count)")

            Text(onboardingState.currentStep.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, DesignTokens.spacingLarge)

            // ViewThatFits prefers the natural layout (Spacers center content);
            // falls back to ScrollView when content can't fit (large Dynamic
            // Type, longer localizations) so the navigation bar stays visible.
            ViewThatFits(in: .vertical) {
                OnboardingStepContent(onboardingState: onboardingState)
                ScrollView {
                    OnboardingStepContent(onboardingState: onboardingState)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

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
        .frame(width: 500, height: 600)
        .background(.ultraThinMaterial)
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

private struct OnboardingStepContent: View {
    let onboardingState: OnboardingState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch onboardingState.currentStep {
            case .welcome:
                OnboardingWelcomeView()
                    .transition(stepTransition)
            case .authenticate:
                OnboardingAuthView()
                    .transition(stepTransition)
            case .selectApp:
                OnboardingAppSelectionView()
                    .transition(stepTransition)
            case .preferences:
                OnboardingPreferencesView()
                    .transition(stepTransition)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: onboardingState.currentStep)
    }

    private var stepTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: onboardingState.isGoingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: onboardingState.isGoingForward ? .leading : .trailing).combined(with: .opacity)
        )
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
