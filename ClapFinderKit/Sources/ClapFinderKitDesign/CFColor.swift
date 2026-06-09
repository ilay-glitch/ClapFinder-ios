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
}
