import CoreFoundation

// swiftlint:disable colon identifier_name

// MARK: - CFRadius

/// Corner radius tokens.
/// Source of truth: DESIGN.md
public enum CFRadius {
    /// 20pt. Cards, bottom sheets.
    public static let card:       CGFloat = 20
    /// 16pt. Buttons, chip controls.
    public static let button:     CGFloat = 16
    /// 14pt. Animal grid cards.
    public static let animalCard: CGFloat = 14
    /// 36pt. Listening toggle circle.
    public static let toggle:     CGFloat = 36
}

// MARK: - CFSpacing

/// Spacing scale — 8pt base grid.
/// Source of truth: DESIGN.md
public enum CFSpacing {
    /// 4pt
    public static let xs:  CGFloat = 4
    /// 8pt
    public static let sm:  CGFloat = 8
    /// 16pt
    public static let md:  CGFloat = 16
    /// 24pt
    public static let lg:  CGFloat = 24
    /// 32pt
    public static let xl:  CGFloat = 32
    /// 48pt
    public static let xxl: CGFloat = 48
}

// swiftlint:enable colon identifier_name
