import Testing
@testable import scrobble

@Suite("AuthState Tests", .serialized)
struct AuthStateTests {

    private func cleanUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
    }

    @Test("Initial state without session key")
    func initialStateNoSession() {
        cleanUserDefaults()
        let state = AuthState()
        #expect(state.isAuthenticated == false)
        #expect(state.isAuthenticating == false)
        #expect(state.showingAuthSheet == false)
        #expect(state.authError == nil)
    }

    @Test("Initial state with session key")
    func initialStateWithSession() {
        UserDefaults.standard.set("test-session-key", forKey: "lastfm_session_key")
        let state = AuthState()
        #expect(state.isAuthenticated == true)
        cleanUserDefaults()
    }

    @Test("startAuth resets error and flags")
    func startAuth() {
        cleanUserDefaults()
        let state = AuthState()
        state.authError = "some error"
        state.startAuth()
        #expect(state.showingAuthSheet == false)
        #expect(state.isAuthenticating == false)
        #expect(state.authError == nil)
    }

    @Test("completeAuth with success sets authenticated")
    func completeAuthSuccess() {
        cleanUserDefaults()
        let state = AuthState()
        state.showingAuthSheet = true
        state.isAuthenticating = true
        state.completeAuth(success: true)
        #expect(state.isAuthenticated == true)
        #expect(state.showingAuthSheet == false)
        #expect(state.isAuthenticating == false)
        #expect(state.authError == nil)
    }

    @Test("completeAuth with failure sets error")
    func completeAuthFailure() {
        cleanUserDefaults()
        let state = AuthState()
        state.completeAuth(success: false)
        #expect(state.isAuthenticated == false)
        #expect(state.showingAuthSheet == false)
        #expect(state.authError != nil)
    }

    @Test("signOut clears session key and state")
    func signOut() {
        UserDefaults.standard.set("test-key", forKey: "lastfm_session_key")
        let state = AuthState()
        #expect(state.isAuthenticated == true)
        state.signOut()
        #expect(state.isAuthenticated == false)
        #expect(state.authError == nil)
        #expect(UserDefaults.standard.string(forKey: "lastfm_session_key") == nil)
    }

    @Test("completeAuth failure message is correct")
    func completeAuthFailureMessage() {
        cleanUserDefaults()
        let state = AuthState()
        state.completeAuth(success: false)
        #expect(state.authError == "Authentication failed or was cancelled")
    }

    @Test("State transition: start then complete success")
    func stateTransitionSuccess() {
        cleanUserDefaults()
        let state = AuthState()
        #expect(state.isAuthenticated == false)
        state.startAuth()
        state.completeAuth(success: true)
        #expect(state.isAuthenticated == true)
    }

    @Test("State transition: failure then retry success")
    func stateTransitionFailureThenSuccess() {
        cleanUserDefaults()
        let state = AuthState()
        state.startAuth()
        state.completeAuth(success: false)
        #expect(state.isAuthenticated == false)
        #expect(state.authError != nil)
        state.startAuth()
        #expect(state.authError == nil)
        state.completeAuth(success: true)
        #expect(state.isAuthenticated == true)
    }

    @Test("signOut after successful auth")
    func signOutAfterAuth() {
        cleanUserDefaults()
        let state = AuthState()
        state.completeAuth(success: true)
        #expect(state.isAuthenticated == true)
        state.signOut()
        #expect(state.isAuthenticated == false)
    }
}
