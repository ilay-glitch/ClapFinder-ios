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

> Note: Phase 2/3 PR numbers below shift by one (ads = PR-10, etc.) now that PR-9 is taken by the Xcode project PR.

## Phase 2 — Monetization + Analytics
Prerequisite: ad network decision (AdMob vs. AppLovin MAX).

| PR | Scope | Status |
|----|-------|--------|
| PR-9  | Ad integration: banner (home bottom) + interstitial (3–5 uses, never during detection) | Pending |
| PR-10 | Firebase Analytics + Adjust attribution | Pending |
| PR-11 | Remote Config: sensitivity thresholds, interstitial frequency, A/B hooks | Pending |
| PR-12 | Polish: confetti/star animation on find, final app icon, TestFlight regression build | Pending |

## Phase 3 — App Store Submission

| PR | Scope | Status |
|----|-------|--------|
| PR-13 | App Store assets: icon, screenshots (6.5", 5.5", iPad 12.9") + metadata + privacy policy | Pending |
| PR-14 | Submission build + App Store review | Pending |
