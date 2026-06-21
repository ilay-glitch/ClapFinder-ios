import SwiftUI

// MARK: - CFGradient

/// Gradient tokens for ClapFinder.
/// Source of truth: DESIGN.md
public enum CFGradient {

    /// Primary brand "gradient": flat solid `ctaBlue` (v-next, DESIGN.md §6).
    /// Use for: toggle active fill, selected animal border, buttons.
    public static let brand = LinearGradient(
        colors: [CFColor.ctaBlue, CFColor.ctaBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Pulse / radar ring strokes: skyTint → ctaBlue.
    public static let pulse = LinearGradient(
        colors: [CFColor.skyTint, CFColor.ctaBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Horizontal variant for sensitivity control active segment: sky → cta.
    public static let brandHorizontal = LinearGradient(
        colors: [CFColor.skyPrimary, CFColor.ctaBlue],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: Splash (deprecated: redesign v-next — removed when Part B rebuilds the splash)

    /// Splash night-scene background. 5 stops at 0/30/55/78/100 %.
    /// Use ONLY on the splash screen — app chrome keeps `brand`.
    public static let splashNight = LinearGradient(
        stops: [
            .init(color: CFColor.splashNight1, location: 0.00),
            .init(color: CFColor.splashNight2, location: 0.30),
            .init(color: CFColor.splashNight3, location: 0.55),
            .init(color: CFColor.splashNight4, location: 0.78),
            .init(color: CFColor.splashNight5, location: 1.00)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Splash title text fill: gold → peach → pink. Splash-only.
    public static let titleGold = LinearGradient(
        colors: [CFColor.splashGold, CFColor.splashPeach, CFColor.splashPink],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Splash progress-bar fill: gold → coral → rose. Splash-only.
    public static let splashBar = LinearGradient(
        colors: [CFColor.splashGold, CFColor.splashCoral, CFColor.splashRose],
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
