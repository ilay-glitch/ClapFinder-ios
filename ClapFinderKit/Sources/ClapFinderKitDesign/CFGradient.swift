import SwiftUI

// MARK: - CFGradient

/// Gradient tokens for ClapFinder.
/// Source of truth: DESIGN.md
public enum CFGradient {

    /// Primary brand gradient: violet → pink → orange.
    /// Use for: toggle active fill, selected animal border, buttons.
    public static let brand = LinearGradient(
        colors: [CFColor.gradientStart, CFColor.gradientMid, CFColor.gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Simplified gradient for pulse ring strokes: violet → orange.
    public static let pulse = LinearGradient(
        colors: [CFColor.gradientStart, CFColor.gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Horizontal variant for sensitivity control active segment.
    public static let brandHorizontal = LinearGradient(
        colors: [CFColor.gradientStart, CFColor.gradientMid],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - CFGradient helpers on ShapeStyle

public extension View {
    /// Fills the view with the brand gradient as a foreground style.
    func brandGradientForeground() -> some View {
        self.foregroundStyle(CFGradient.brand)
    }
}
