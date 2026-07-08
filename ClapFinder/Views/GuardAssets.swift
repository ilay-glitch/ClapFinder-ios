import UIKit

// MARK: - GuardAssets

/// Asset slots for the P3 guard art (PIVOT.md §6). The PM-generated images
/// land late in the sprint; every view resolves through here so the art drops
/// in with **zero code changes** — until then each slot falls back to the
/// existing detective art (or renders nothing for net-new slots like the
/// Home background).
enum GuardAssets {

    /// Returns `name` if present in the asset catalog, else `fallback` if
    /// present, else nil.
    static func imageName(_ name: String, fallback: String? = nil) -> String? {
        if UIImage(named: name) != nil { return name }
        if let fallback, UIImage(named: fallback) != nil { return fallback }
        return nil
    }

    // The P3 slots (arrive as imagesets named exactly like this):
    static var homeBackground: String? { imageName("guard_dog_home_background") }
    static var heroDisarmed: String? { imageName("guard_dog_shield") }
    static var heroArmed: String? { imageName("guard_dog_watching", fallback: "guard_dog_shield") }
    static var alarmBarking: String? { imageName("guard_dog_barking") }
    static var onboardingWave: String? { imageName("guard_dog_wave", fallback: "detective_dog_wave") }
    static var onboardingReady: String? { imageName("guard_dog_shield", fallback: "detective_dog_phone") }
    static var splashHero: String? { imageName("guard_dog_shield", fallback: "detective_dog_phone") }
}
