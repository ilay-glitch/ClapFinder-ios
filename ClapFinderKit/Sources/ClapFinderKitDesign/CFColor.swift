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

    // MARK: Backgrounds
    /// Deep purple-black. Primary screen background.
    public static let backgroundPrimary  = Color(cfHex: 0x0D0818)
    /// Elevated surface. Nav bar, ad container, sheets.
    public static let backgroundElevated = Color(cfHex: 0x1A0F2E)

    // MARK: Surfaces
    /// Frosted card background. rgba(255,255,255,0.07).
    public static let surfaceCard   = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.07)
    /// Subtle border. rgba(255,255,255,0.10).
    public static let borderSubtle  = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.10)

    // MARK: Brand gradient anchors
    /// Violet — gradient start.
    public static let gradientStart = Color(cfHex: 0x8B5CF6)
    /// Pink — gradient mid.
    public static let gradientMid   = Color(cfHex: 0xEC4899)
    /// Orange — gradient end.
    public static let gradientEnd   = Color(cfHex: 0xF97316)

    // MARK: Text
    /// Full white.
    public static let textPrimary   = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1.00)
    /// 65% white.
    public static let textSecondary = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.65)
    /// 40% white. Placeholders, tertiary labels.
    public static let textTertiary  = Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 0.40)

    // MARK: Semantic
    /// Green. "Listening" active indicator dot.
    public static let listeningActive  = Color(cfHex: 0x22C55E)
    /// Cyan. "Found!" celebration state flash.
    public static let celebrationCyan  = Color(cfHex: 0x22D3EE)
    /// Ad container background. Same as backgroundElevated.
    public static let adContainer      = Color(cfHex: 0x1A0F2E)

    // MARK: Splash (LOADING_SCREEN_MOCKUP.html — splash-screen-only, DESIGN.md)

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
