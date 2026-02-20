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
    /// Applies a glass effect on macOS 26+, or an ultrathin material background on macOS 15+
    @ViewBuilder
    func compatGlass(in shape: RoundedRectangle = RoundedRectangle(cornerRadius: 8)) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }

    /// Applies a glass effect with custom corner radius
    @ViewBuilder
    func compatGlass(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Applies a clear glass effect on macOS 26+, or a subtle overlay on macOS 15+
    @ViewBuilder
    func compatGlassClear() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.clear)
        } else {
            self.background(.ultraThinMaterial.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
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
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.2)
                            : configuration.isPressed
                                ? Color.primary.opacity(0.08)
                                : Color.primary.opacity(0.04)
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

// MARK: - Button Style Extensions

extension View {
    /// Applies glass button styling with backwards compatibility
    @ViewBuilder
    func compatGlassButtonStyle(selected: Bool = false) -> some View {
        if #available(macOS 26, *) {
            self
                .tint(selected ? .accentColor : .clear)
                .buttonStyle(selected ? .glass(.regular.tint(.accentColor)) : .glass)
        } else {
            self.buttonStyle(CompatGlassButtonStyleLegacy(isSelected: selected))
        }
    }
}
