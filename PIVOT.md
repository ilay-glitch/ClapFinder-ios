# PIVOT.md — ClapFinder → Guard Dog ("Don't Touch My Phone")

**Decision:** 2026-07-02 (PM). **Docs:** this file + DESIGN.md pivot note +
ONBOARDING_DESIGN.md v2. **Shape note redlined & approved 2026-07-02.**

---

## 1. The decision

Clap detection **failed reliability QA** after extensive, well-documented work
(three detector generations, two measured root-causes, a device-measured
ambient false-positive rate of 6.7–15.6 ACCEPTs/min in a TV room — see §4).
Meanwhile the winning ad creative sells the *other* feature. The product
pivots: **Touch Alert ("don't touch my phone") becomes THE product.** Clap
detection is removed from the app — **UI and app target only**; all detection
code and its documentation remain in the repo, dormant and recoverable.

## 2. New identity

| Item | Ruling |
|---|---|
| **Name** | **"Guard Dog — Don't Touch My Phone"** (PM ruling, 2026-07-02) |
| **Bundle ID** | **NEW** bundle ID + fresh listing (never shipped publicly; clean identity wins). Proposed: `com.appcentral.guarddog` — final string is the PM's at P3. |
| **Mascot** | Same detective-dog character, new job: **guard dog** — loyal protector, barks at intruders. New pose set at P3 (§6). |
| **Creative structure to mirror** | Cute character grid as centerpiece (the 16 sounds = "guards"), single big **"Tap to activate"** action. **No tab bar at launch** (single mode; add when a second mode exists — PM ruling b2). |
| **Palette** | Sky-blue system (DESIGN.md v-next) unchanged. |

## 3. Staging — four sequential PRs off main (approved)

| PR | Scope | Gate |
|---|---|---|
| **P0** | This doc + DESIGN.md pivot note + ONBOARDING_DESIGN.md v2 | PM redline (done) |
| **P1** | The cut (clap UI/strings/analytics out of the app target) + Touch-Alert-as-Home reskin + onboarding rescope | tests green; app is the guard product; mic still present |
| **P2** | **Mic removal**: keep-alive swap to playback-only silent loop; delete `NSMicrophoneUsageDescription`; onboarding step-2 → notifications-only | **own device QA gate**: lock-screen survival, interruption recovery, watchdog notification path |
| **P3** | Guard assets (PM-generated), app icon, display name + new bundle ID, splash hero swap | PM visual review on device |

## 4. What is removed vs. dormant (the recoverability map)

**Removed from the app target (P1):** Clap mode UI (`ModeSwitcherView`,
`ListeningToggleView`, `PulseRingsView`, `ClapCalibrationSheet`), clap flows in
`HomeView`/`OnboardingView`, clap strings, clap Live Activity, clap analytics
from active flows.

**Dormant in ClapFinderKit (NOT deleted):** `ClapDetector` (+Calibration,
+AudioSession, +Diagnostics, +Spectral extensions), `ClapSpectral`,
`ClapCalibration`, `ClapCalibrationController`, `ClapDiagnostics`,
`ClapClassifierProbe`, `ResponseSuppression`, and all their tests.
**Note:** `ClapDetector` remains *live but silent* as the touch-alert
keep-alive until P2 swaps it out; after P2 it is fully dormant.

**The detection archive (all on main):** SOUND_RECOGNITION_DESIGN.md (v2→v4 +
§13 device findings + §15 response guards), CLAP_DIAGNOSTICS.md,
SOUND_ANALYSIS_INVESTIGATION.md (closed verdict), and the PR trail #15→#40.
Merging #39/#40 before the pivot was deliberate: **main is the archive.**

## 5. The mic-permission removal (P2 — approved)

Today the touch alert's background survival is a `ClapDetector` mic tap
(`.playAndRecord`). P2 replaces it with a **playback-only silent audio loop**
(`.playback`, mixWithOthers, same `UIBackgroundModes: audio`), deleting the
record path and the mic permission entirely. **"No microphone access" is a
category-defining privacy line for a phone-guard app.** Known risk: silent-loop
background audio is an App Review gray area — mitigated because the audible
alarm genuinely uses the audio session. P2 ships only through its device QA
gate (§3).

## 6. Asset poses (PM generates; same character, 1254², bg ≈ #5BB8FF)

`guard_dog_shield` (Home hero) · `guard_dog_watching` (armed state) ·
`guard_dog_barking` (alarm overlay) · `guard_dog_wave` (onboarding welcome;
existing wave may be reused) · `guard_dog_icon` (App Icon, fully opaque).

## 7. Fences (unchanged by the pivot)

Ads/monetization policy untouched (App Open Ad rules, banner idle-only,
interstitial counter). Touch-alert *logic* (CoreMotion, alarm, notification
watchdog) is proven — P1 reskins and promotes it, **no rewrite**. Sound
catalog: all 16 sounds stay, re-framed as the guard grid.
