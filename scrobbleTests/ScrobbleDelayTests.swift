import Testing
@testable import scrobble

@Suite("Scrobble Delay Tests")
struct ScrobbleDelayTests {

    @Test("Returns nil for tracks under 30 seconds")
    func shortTrackReturnsNil() {
        let delay = calculateScrobbleDelay(trackDuration: 25, completionPercentage: 50, useMaxDelay: false, maxDelay: nil)
        #expect(delay == nil)
    }

    @Test("Returns nil for exactly 30-second tracks")
    func exactlyThirtySecondsReturnsNil() {
        let delay = calculateScrobbleDelay(trackDuration: 30, completionPercentage: 50, useMaxDelay: false, maxDelay: nil)
        #expect(delay == nil)
    }

    @Test("50% of a 200-second track is 100 seconds")
    func fiftyPercentDelay() {
        let delay = calculateScrobbleDelay(trackDuration: 200, completionPercentage: 50, useMaxDelay: false, maxDelay: nil)
        #expect(delay == 100.0)
    }

    @Test("75% of a 200-second track is 150 seconds")
    func seventyFivePercentDelay() {
        let delay = calculateScrobbleDelay(trackDuration: 200, completionPercentage: 75, useMaxDelay: false, maxDelay: nil)
        #expect(delay == 150.0)
    }

    @Test("Max delay caps the scrobble delay")
    func maxDelayCaps() {
        let delay = calculateScrobbleDelay(trackDuration: 600, completionPercentage: 50, useMaxDelay: true, maxDelay: 240)
        #expect(delay == 240.0)
    }

    @Test("Max delay does not affect shorter delays")
    func maxDelayNoEffectOnShorterDelay() {
        let delay = calculateScrobbleDelay(trackDuration: 200, completionPercentage: 50, useMaxDelay: true, maxDelay: 240)
        #expect(delay == 100.0)
    }

    @Test("Max delay disabled uses full percentage delay")
    func maxDelayDisabled() {
        let delay = calculateScrobbleDelay(trackDuration: 600, completionPercentage: 50, useMaxDelay: false, maxDelay: 240)
        #expect(delay == 300.0)
    }

    @Test("100% completion equals full duration")
    func fullCompletionPercentage() {
        let delay = calculateScrobbleDelay(trackDuration: 180, completionPercentage: 100, useMaxDelay: false, maxDelay: nil)
        #expect(delay == 180.0)
    }
}
