/// ClapFinderKitAds
///
/// Ad infrastructure for ClapFinder.
///
/// Phase 1: `ATTManager` — requests App Tracking Transparency consent on first launch.
/// Phase 2: Ad network integration (AdMob or AppLovin MAX — decision pending).
///          Banner (home bottom) + interstitial (3–5 uses, never during detection).
///
/// Rule: Do NOT add ad SDK dependencies until the Phase 2 network decision is made.
public enum ClapFinderKitAds {}
