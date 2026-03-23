//
//  DesignTokens.swift
//  scrobble
//
//  Centralized design constants for consistent styling across the app.
//

import SwiftUI

enum DesignTokens {

    // MARK: - Corner Radii

    /// Buttons, small controls (6pt)
    static let cornerRadiusSmall: CGFloat = 6

    /// Cards, containers, glass surfaces (10pt)
    static let cornerRadiusMedium: CGFloat = 10

    /// Onboarding cards, large interactive surfaces (12pt)
    static let cornerRadiusLarge: CGFloat = 12

    // MARK: - Spacing

    /// Tight spacing for inline elements (4pt)
    static let spacingTight: CGFloat = 4

    /// Default spacing between related items (8pt)
    static let spacingDefault: CGFloat = 8

    /// Spacing between sections or groups (12pt)
    static let spacingSection: CGFloat = 12

    /// Generous spacing between major sections (16pt)
    static let spacingLarge: CGFloat = 16

    // MARK: - Content Padding

    /// Standard horizontal content padding (32pt) — onboarding, modal content
    static let contentPaddingHorizontal: CGFloat = 32

    /// Standard inner padding for cards/containers (12pt)
    static let cardPadding: CGFloat = 12

    // MARK: - Artwork

    /// Now-playing artwork size in menu bar popover
    static let artworkSizeSmall: CGFloat = 50

    /// Track artwork thumbnail in lists
    static let artworkSizeThumbnail: CGFloat = 40

    /// Small inline track artwork in friend cards
    static let artworkSizeInline: CGFloat = 24

    // MARK: - Onboarding

    /// SF Symbol icon size for onboarding step headers
    static let onboardingIconSize: CGFloat = 40
}
