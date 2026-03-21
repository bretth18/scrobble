import Testing
@testable import scrobble

@Suite("AuthState Tests", .serialized)
@MainActor
struct AuthStateTests {

    private func cleanAuth() {
        KeychainHelper.delete(key: "lastfm_session_key")
        KeychainHelper.delete(key: "lastfm_username")
        UserDefaults.standard.removeObject(forKey: "lastfm_session_key")
    }

    @Test("Initial state without session key")
    func initialStateNoSession() {
        cleanAuth()
        let state = AuthState()
        #expect(state.isAuthenticated == false)
        #expect(state.isAuthenticating == false)
        #expect(state.showingAuthSheet == false)
        #expect(state.authError == nil)
    }

    @Test("Initial state with session key in Keychain")
    func initialStateWithSession() {
        _ = KeychainHelper.save(key: "lastfm_session_key", value: "test-session-key")
        let state = AuthState()
        #expect(state.isAuthenticated == true)
        cleanAuth()
    }

    @Test("Initial state with legacy UserDefaults session key")
    func initialStateWithLegacySession() {
        cleanAuth()
        UserDefaults.standard.set("test-legacy-key", forKey: "lastfm_session_key")
        let state = AuthState()
        #expect(state.isAuthenticated == true)
        cleanAuth()
    }

    @Test("startAuth resets error and flags")
    func startAuth() {
        cleanAuth()
        let state = AuthState()
        state.authError = "some error"
        state.startAuth()
        #expect(state.showingAuthSheet == false)
        #expect(state.isAuthenticating == false)
        #expect(state.authError == nil)
    }

    @Test("completeAuth with success sets authenticated")
    func completeAuthSuccess() {
        cleanAuth()
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
        cleanAuth()
        let state = AuthState()
        state.completeAuth(success: false)
        #expect(state.isAuthenticated == false)
        #expect(state.showingAuthSheet == false)
        #expect(state.authError != nil)
    }

    @Test("signOut clears session key and state")
    func signOut() {
        _ = KeychainHelper.save(key: "lastfm_session_key", value: "test-key")
        let state = AuthState()
        #expect(state.isAuthenticated == true)
        state.signOut()
        #expect(state.isAuthenticated == false)
        #expect(state.authError == nil)
        #expect(KeychainHelper.load(key: "lastfm_session_key") == nil)
    }

    @Test("completeAuth failure message is correct")
    func completeAuthFailureMessage() {
        cleanAuth()
        let state = AuthState()
        state.completeAuth(success: false)
        #expect(state.authError == "Authentication failed or was cancelled")
    }

    @Test("State transition: start then complete success")
    func stateTransitionSuccess() {
        cleanAuth()
        let state = AuthState()
        #expect(state.isAuthenticated == false)
        state.startAuth()
        state.completeAuth(success: true)
        #expect(state.isAuthenticated == true)
    }

    @Test("State transition: failure then retry success")
    func stateTransitionFailureThenSuccess() {
        cleanAuth()
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
        cleanAuth()
        let state = AuthState()
        state.completeAuth(success: true)
        #expect(state.isAuthenticated == true)
        state.signOut()
        #expect(state.isAuthenticated == false)
    }
}
