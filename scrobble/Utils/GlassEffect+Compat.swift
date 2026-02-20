//
//  GlassEffect+Compat.swift
//  scrobble
//
//  Created by Brett Henderson on 12/12/25.
//  Backwards compatibility layer for glass effects (macOS 15+)
//

import SwiftUI

// MARK: - Adaptive Glass Effect Modifier

extension View {
    /// Applies a glass effect on macOS 26+, or a subtle fill on macOS 15+.
    /// Uses a light fill fallback instead of material to avoid double-material layering
    /// when rendered inside material-backed containers (menu bar popover, etc).
    @ViewBuilder
    func compatGlass(
        cornerRadius: CGFloat = DesignTokens.cornerRadiusMedium
    ) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
    }

    /// Applies a clear glass effect on macOS 26+, or a very subtle fill on macOS 15+
    @ViewBuilder
    func compatGlassClear(
        cornerRadius: CGFloat = DesignTokens.cornerRadiusMedium
    ) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.clear, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(
                Color.primary.opacity(0.02),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        }
    }

    /// Applies scroll edge effect style on macOS 26+, no-op on macOS 15+
    @ViewBuilder
    func compatScrollEdgeEffectStyle() -> some View {
        if #available(macOS 26, *) {
            self.scrollEdgeEffectStyle(.soft, for: .all)
        } else {
            self
        }
    }
}

// MARK: - Glass Effect Container

/// Wraps content in a GlassEffectContainer on macOS 26+ for proper rendering
/// performance and morphing transitions. No-op container on macOS 15.
struct CompatGlassContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(
        spacing: CGFloat = DesignTokens.spacingDefault,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) {
                content
            }
        } else {
            content
        }
    }
}

// MARK: - Adaptive Glass Button Style

/// On macOS 15, provides a lightweight fallback for glass buttons.
/// Uses a subtle fill instead of material to avoid double-material layering
/// when rendered on surfaces that already have .ultraThinMaterial.
struct CompatGlassButtonStyleLegacy: ButtonStyle {
    var isSelected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.2)
                            : configuration.isPressed
                                ? Color.primary.opacity(0.08)
                                : Color.primary.opacity(0.04)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusSmall))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - Button Style Extensions

extension View {
    /// Applies glass button styling with backwards compatibility.
    /// On macOS 26, uses native .glass button style.
    /// On macOS 15, uses a subtle fill-based style.
    @ViewBuilder
    func compatGlassButtonStyle(selected: Bool = false) -> some View {
        if #available(macOS 26, *) {
            self.buttonStyle(
                selected
                    ? .glass(.regular.tint(.accentColor))
                    : .glass
            )
        } else {
            self.buttonStyle(CompatGlassButtonStyleLegacy(isSelected: selected))
        }
    }
}
