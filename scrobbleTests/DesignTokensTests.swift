import Testing
@testable import scrobble

@Suite("DesignTokens Tests")
struct DesignTokensTests {

    @Test("All corner radii are positive")
    func cornerRadiiPositive() {
        #expect(DesignTokens.cornerRadiusSmall > 0)
        #expect(DesignTokens.cornerRadiusMedium > 0)
        #expect(DesignTokens.cornerRadiusLarge > 0)
    }

    @Test("Corner radii are in ascending order")
    func cornerRadiiOrdering() {
        #expect(DesignTokens.cornerRadiusSmall < DesignTokens.cornerRadiusMedium)
        #expect(DesignTokens.cornerRadiusMedium < DesignTokens.cornerRadiusLarge)
    }

    @Test("All spacing values are positive")
    func spacingPositive() {
        #expect(DesignTokens.spacingTight > 0)
        #expect(DesignTokens.spacingDefault > 0)
        #expect(DesignTokens.spacingSection > 0)
        #expect(DesignTokens.spacingLarge > 0)
    }

    @Test("Spacing values are in ascending order")
    func spacingOrdering() {
        #expect(DesignTokens.spacingTight < DesignTokens.spacingDefault)
        #expect(DesignTokens.spacingDefault < DesignTokens.spacingSection)
        #expect(DesignTokens.spacingSection < DesignTokens.spacingLarge)
    }

    @Test("All other constants are positive")
    func otherConstantsPositive() {
        #expect(DesignTokens.artworkSizeSmall > 0)
        #expect(DesignTokens.artworkSizeThumbnail > 0)
        #expect(DesignTokens.contentPaddingHorizontal > 0)
        #expect(DesignTokens.cardPadding > 0)
        #expect(DesignTokens.onboardingIconSize > 0)
    }
}
