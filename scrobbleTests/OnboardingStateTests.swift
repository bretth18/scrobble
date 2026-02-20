import Testing
@testable import scrobble

@Suite("OnboardingState Tests")
struct OnboardingStateTests {

    @Test("Initial state is welcome")
    func initialState() {
        let state = OnboardingState()
        #expect(state.currentStep == .welcome)
    }

    @Test("Initial isGoingForward is true")
    func initialDirection() {
        let state = OnboardingState()
        #expect(state.isGoingForward == true)
    }

    @Test("next() advances from welcome to authenticate")
    func nextFromWelcome() {
        let state = OnboardingState()
        state.next()
        #expect(state.currentStep == .authenticate)
    }

    @Test("next() advances through all steps in order")
    func nextThroughAllSteps() {
        let state = OnboardingState()
        state.next()
        #expect(state.currentStep == .authenticate)
        state.next()
        #expect(state.currentStep == .selectApp)
        state.next()
        #expect(state.currentStep == .preferences)
    }

    @Test("next() sets isGoingForward to true")
    func nextSetsForward() {
        let state = OnboardingState()
        state.isGoingForward = false
        state.next()
        #expect(state.isGoingForward == true)
    }

    @Test("back() goes to previous step")
    func backToPrevious() {
        let state = OnboardingState()
        state.next() // authenticate
        state.back()
        #expect(state.currentStep == .welcome)
    }

    @Test("back() sets isGoingForward to false")
    func backSetsBackward() {
        let state = OnboardingState()
        state.next()
        state.back()
        #expect(state.isGoingForward == false)
    }

    @Test("next() at last step does nothing")
    func nextAtLastStep() {
        let state = OnboardingState()
        state.next() // authenticate
        state.next() // selectApp
        state.next() // preferences (last)
        state.next() // should stay
        #expect(state.currentStep == .preferences)
    }

    @Test("back() at first step does nothing")
    func backAtFirstStep() {
        let state = OnboardingState()
        state.back()
        #expect(state.currentStep == .welcome)
    }

    @Test("Step titles are correct")
    func stepTitles() {
        #expect(OnboardingState.Step.welcome.title == "Welcome")
        #expect(OnboardingState.Step.authenticate.title == "Connect Last.fm")
        #expect(OnboardingState.Step.selectApp.title == "Select App")
        #expect(OnboardingState.Step.preferences.title == "Preferences")
    }

    @Test("Step isFirst property")
    func stepIsFirst() {
        #expect(OnboardingState.Step.welcome.isFirst == true)
        #expect(OnboardingState.Step.authenticate.isFirst == false)
        #expect(OnboardingState.Step.selectApp.isFirst == false)
        #expect(OnboardingState.Step.preferences.isFirst == false)
    }

    @Test("Step isLast property")
    func stepIsLast() {
        #expect(OnboardingState.Step.welcome.isLast == false)
        #expect(OnboardingState.Step.authenticate.isLast == false)
        #expect(OnboardingState.Step.selectApp.isLast == false)
        #expect(OnboardingState.Step.preferences.isLast == true)
    }

    @Test("canProceed returns true for welcome regardless of auth")
    func canProceedWelcome() {
        let state = OnboardingState()
        let auth = AuthState()
        auth.isAuthenticated = false
        #expect(state.canProceed(authState: auth) == true)
    }

    @Test("canProceed returns false for authenticate when not authenticated")
    func canProceedAuthNotAuthenticated() {
        let state = OnboardingState()
        state.next() // authenticate
        let auth = AuthState()
        auth.isAuthenticated = false
        #expect(state.canProceed(authState: auth) == false)
    }

    @Test("canProceed returns true for authenticate when authenticated")
    func canProceedAuthAuthenticated() {
        let state = OnboardingState()
        state.next() // authenticate
        let auth = AuthState()
        auth.isAuthenticated = true
        #expect(state.canProceed(authState: auth) == true)
    }
}
