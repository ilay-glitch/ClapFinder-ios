# ClapFinder — Plan

## Phase 1 — Core MVP (no ads)
Target: TestFlight build with full clap detection + animal sounds + flashlight + UI. No ad SDK. Real-device QA closes the phase.

| PR | Scope | Status |
|----|-------|--------|
| PR-1 | Repo scaffold: ClapFinderKit SPM + directory structure + lint CI | In progress |
| PR-2 | Design tokens: ClapFinderKitDesign module. DESIGN.md v3 signoff before code. | Pending |
| PR-3 | Data layer: Animal model + catalog.json (16 animals) + ClapFinderKitData | Pending |
| PR-4 | Clap detection engine: AVAudioEngine tap + RMS + 2-clap-in-500ms (ClapFinderKitAudio) | Pending |
| PR-5 | Response layer: sound playback at max volume + flashlight 3× pulse | Pending |
| PR-6 | Home UI: listening animation + animal grid + sensitivity control + toggle | Pending |
| PR-7 | Background mode: AVAudioSession config + UIBackgroundModes + mic permission | Pending |
| PR-8 | ATT prompt: App Tracking Transparency + family-appropriate copy | Pending |
| PR-9 | Xcode project: xcodegen project.yml + app icon placeholder + Swift 6 isolation fixes + device QA log (MIGRATION_VALIDATION.md) | In progress |

Real-device QA required to close Phase 1: mic detection (all 3 sensitivity levels), background clap (screen off, 10+ min), flashlight 3× pulse, audio at max volume in silent mode, ATT prompt first-launch flow. Results are recorded in `MIGRATION_VALIDATION.md`.

## Phase 2 — Monetization + Analytics
Ad network: **AdMob** (PM decision, locked in PR-10 — app open is the anchor placement).

| PR | Scope | Status |
|----|-------|--------|
| PR-10 | Splash screen + AdMob App Open Ad (SPLASH_DESIGN.md, EVENTS.md created) | In progress |
| PR-11 | Touch/Motion Alert: arm/disarm, CoreMotion detection, alarm loop (TOUCH_ALERT_DESIGN.md) | In progress |
| PR-12 | Ad integration: banner (home bottom) + interstitial (3–5 uses, never during detection) | Pending |
| PR-13 | Firebase Analytics + Adjust attribution. Includes extracting `AnalyticsClient` from ClapFinderKitAds into its own module — removes the Motion→Ads dependency edge (acknowledged debt from PR-11) | Pending |
| PR-14 | Remote Config: sensitivity thresholds, interstitial frequency, A/B hooks | Pending |
| PR-15 | Polish: confetti/star animation on find, final app icon, TestFlight regression build | Pending |

> Numbering: PR-9 (Xcode project) shifted Phase 2 by one; the splash
> PR took PR-10. Touch alert takes PR-11 — core-feature completeness
> before the second ad layer (PM ruling 2026-06-11) — pushing
> ads/analytics/config/polish to PR-12–15 and Phase 3 to PR-16/17.
>
> GitHub PR mapping (GitHub numbers PRs and issues in one sequence, so
> they drift from logical PR numbers): logical PR-9 = GitHub #9,
> logical PR-10 = GitHub #11.

## Phase 3 — App Store Submission

| PR | Scope | Status |
|----|-------|--------|
| PR-16 | App Store assets: icon, screenshots (6.5", 5.5", iPad 12.9") + metadata + privacy policy | Pending |
| PR-17 | Submission build + App Store review | Pending |
