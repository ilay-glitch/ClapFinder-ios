import SwiftUI

// MARK: - CFFont

/// Typography scale for ClapFinder — SF Rounded throughout.
/// Source of truth: DESIGN.md
public enum CFFont {
    /// 34pt Bold. App title.
    public static func display() -> Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }
    /// 28pt Bold. Section headers.
    public static func title1() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    /// 22pt Semibold. Card titles.
    public static func title2() -> Font {
        .system(size: 22, weight: .semibold, design: .rounded)
    }
    /// 17pt Semibold. Selected animal name, row labels.
    public static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .rounded)
    }
    /// 16pt Regular. Body copy.
    public static func body() -> Font {
        .system(size: 16, weight: .regular, design: .rounded)
    }
    /// 15pt Regular. Supporting / hint text.
    public static func callout() -> Font {
        .system(size: 15, weight: .regular, design: .rounded)
    }
    /// 12pt Regular. Animal grid labels, timestamps.
    public static func caption() -> Font {
        .system(size: 12, weight: .regular, design: .rounded)
    }
}
