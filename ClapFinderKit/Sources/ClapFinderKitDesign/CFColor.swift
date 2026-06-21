import SwiftUI

// MARK: - Hex helper (ClapFinderKitDesign only)

extension Color {
    // Initialise a Color from a 24-bit hex literal.
    // Only call this from ClapFinderKitDesign — hex literals are banned elsewhere.
    init(cfHex hex: UInt32, opacity: Double = 1.0) {
        // swiftlint:disable identifier_name
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8)  & 0xFF) / 255.0
        let b = Double(hex         & 0xFF) / 255.0
        // swiftlint:enable identifier_name
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

// MARK: - CFColor

/// Canonical color tokens for ClapFinder.
/// Source of truth: DESIGN.md
public enum CFColor {

    // MARK: Sky (v-next primary palette — DESIGN.md §2)
    /// Sky blue. Primary screen background (ambient field). Character art is
    /// normalised to this value.
    public static let skyPrimary = Color(cfHex: 0x5BB8FF)
    /// Lighter sky. Ring gradients, section tints.
    public static let skyTint    = Color(cfHex: 0xA8DCFF)
    /// White. Cards, sheets, nav, ad container.
    public static let surface    = Color(cfHex: 0xFFFFFF)
    /// Warm cream. Alt cards, callouts.
    public static let cream      = Color(cfHex: 0xF5EEE0)
    /// Strong CTA blue. Primary buttons / Continue (flat, solid).
    public static let ctaBlue    = Color(cfHex: 0x2D7FF9)

    // MARK: Backgrounds (deprecated: redesign v-next — use skyPrimary / surface)
    /// - deprecated: use `skyPrimary`.
    public static let backgroundPrimary  = skyPrimary
    /// - deprecated: use `surface`.
    public static let backgroundElevated = surface

    // MARK: Surfaces
    /// Card background (white on the light theme).
    public static let surfaceCard   = surface
    /// Subtle border/divider. Navy at 10%.
    public static let borderSubtle  = Color(cfHex: 0x14233D, opacity: 0.10)

    // MARK: Brand gradient anchors (deprecated: redesign v-next — kept for one release)
    /// - deprecated: violet anchor, no longer referenced.
    public static let gradientStart = Color(cfHex: 0x8B5CF6)
    /// - deprecated: pink anchor, no longer referenced.
    public static let gradientMid   = Color(cfHex: 0xEC4899)
    /// - deprecated: orange anchor, no longer referenced.
    public static let gradientEnd   = Color(cfHex: 0xF97316)

    // MARK: Text (navy on light surfaces — AA/AAA, DESIGN.md §8)
    /// Navy. Primary text. 15.7:1 on white, 13.6:1 on cream.
    public static let textPrimary   = Color(cfHex: 0x14233D, opacity: 1.00)
    /// Navy 60%. Secondary text.
    public static let textSecondary = Color(cfHex: 0x14233D, opacity: 0.60)
    /// Navy 40%. Placeholders, tertiary labels.
    public static let textTertiary  = Color(cfHex: 0x14233D, opacity: 0.40)

    // MARK: Semantic
    /// Green. "Listening" active indicator dot.
    public static let listeningActive  = Color(cfHex: 0x22C55E)
    /// Cyan. "Found!" celebration state flash.
    public static let celebrationCyan  = Color(cfHex: 0x22D3EE)
    /// Ad container background (white on the light theme).
    public static let adContainer      = surface

    // MARK: Splash (deprecated: redesign v-next — removed when Part B rebuilds the splash)

    /// Splash moon radial center.
    public static let splashMoonCore   = Color(cfHex: 0xFFF8D6)
    /// Splash moon radial edge, glow, and sound-wave arcs.
    public static let splashMoonEdge   = Color(cfHex: 0xFFD96B)
    /// Splash back hill.
    public static let splashHillBack   = Color(cfHex: 0x5C2475)
    /// Splash front hill.
    public static let splashHillFront  = Color(cfHex: 0x471D62)
    /// Splash progress-bar glow (coral, used at 0.8 opacity).
    public static let splashBarGlow    = Color(cfHex: 0xFF8A5C)

    // MARK: Splash gradient anchors (used only by CFGradient splash tokens)

    static let splashNight1 = Color(cfHex: 0x2B1055)
    static let splashNight2 = Color(cfHex: 0x4A1A6B)
    static let splashNight3 = Color(cfHex: 0x7B2D8B)
    static let splashNight4 = Color(cfHex: 0xC44B8C)
    static let splashNight5 = Color(cfHex: 0xF0735A)
    static let splashGold   = Color(cfHex: 0xFFD96B)
    static let splashPeach  = Color(cfHex: 0xFF9D6B)
    static let splashPink   = Color(cfHex: 0xFF6BB5)
    static let splashCoral  = Color(cfHex: 0xFF8A5C)
    static let splashRose   = Color(cfHex: 0xFF5CA8)
}
