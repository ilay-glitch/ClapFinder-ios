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
| **Name** | **"Guard Dog — Don't Touch My Phone"** (PM ruling, 2026-07-02). Implemented P3: device icon label `CFBundleDisplayName` = **"Guard Dog"** (iOS truncates ~14 chars); App Store listing name = **"Guard Dog — Don't Touch Phone"** (29 chars — the full ruling name is 32, over ASC's 30 limit; "My" dropped, full phrase goes in the subtitle/keywords). |
| **Bundle ID** | **NEW** bundle ID + fresh listing (never shipped publicly; clean identity wins). **Implemented P3: `com.appcentral.guarddog`** (+ `.widgets` for the extension). Internal code/project names stay `ClapFinder*` deliberately — an internal codename; renaming the package modules would be pure churn. |
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
`ClapClassifierProbe`, `ResponseSuppression`, `ResponseCoordinator` (unwired since P1), and all their tests. (`AlarmResponder`/`SoundPlayer`/`FlashlightController`/`HapticController` stay LIVE — the guard uses them.)
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
gate (§3). **Implemented 2026-07-08 (`pivot/p2-mic-removal`)** — `SilentKeepAlive`
(playback-only silent loop) replaces the ClapDetector mic tap; the mic
permission and `NSMicrophoneUsageDescription` are gone; `ClapDetector` is now
fully dormant.

## 6. Asset poses (PM generates; same character, 1254², bg ≈ #5BB8FF)

`guard_dog_shield` (Home hero) · `guard_dog_watching` (armed state) ·
`guard_dog_barking` (alarm overlay) · `guard_dog_wave` (onboarding welcome;
existing wave may be reused) · `guard_dog_icon` (App Icon, fully opaque).

## 6b. Known platform limitation — flashlight on locked alarms

The alarm flashlight cannot fire while the phone is locked/backgrounded:
`AVCaptureDevice` torch is camera-subsystem hardware and iOS restricts it to
foreground apps (background torch writes are silently ignored; the system
force-disables the torch when an app backgrounds; no entitlement exists).
Verified 2026-07-08: our `FlashlightController` attempts unconditionally on the
alarm path — the OS gates it. The alarm **sound** is the primary defense and
works from locked (QA M7 ✅); the torch self-recovers the moment the app is
foregrounded during an active alarm.

## 6c. Known platform limitation — accessibility LED on local notifications

"LED Flash for Alerts" does not fire for our alarm notifications. Established
empirically 2026-07-09 (iOS 26.5, iPhone 15), three-point isolation with
file-based delivery diagnostics (`notifdiag.csv`):

- Control: a WhatsApp remote push on the same device/settings DOES blink.
- Our locally scheduled notifications were verifiably scheduled (`add`
  error=nil), fully authorized (lockScreen setting enabled), and delivered on
  the locked screen via the normal path (app `.background`, no `willPresent`)
  — and did not blink, in all three states: mid-alarm (audio blaring),
  armed-quiet (silent keep-alive only), and idle-quiet (no audio session, app
  suspended, screen off — the perfect-conditions mirror of the control).

No public API influences the LED, and every documented user-facing condition
(locked, lock-screen notifications enabled, per-app notifications on) was
satisfied per the diagnostics rows. Conclusion: on current iOS the LED fires
for remote pushes but not for third-party locally scheduled notifications —
unreachable for a serverless local alarm. Not documented by Apple; empirical.
The in-app LED-tip copy was rewritten to promise only what works (sound).
Post-launch option parked in §8.

## 7. Fences (unchanged by the pivot)

Ads/monetization policy untouched (App Open Ad rules, banner idle-only,
interstitial counter). Touch-alert *logic* (CoreMotion, alarm, notification
watchdog) is proven — P1 reskins and promotes it, **no rewrite**. Sound
catalog: all 16 sounds stay, re-framed as the guard grid.


## 8. Post-launch list

- **Critical Alerts entitlement application** (`com.apple.developer.
  usernotifications.critical-alerts`): lets the alarm notification's sound
  bypass the silent switch and Focus even if the app process is dead —
  robustness layer on top of the in-app alarm audio. Security justification to
  submit: an anti-theft alarm that a thief can defeat by Focus/silent is not an
  alarm; the notification is the theft-moment alert. Manual Apple review
  (days–weeks, resubmissions common) — deliberately NOT a v1 gate.
- **Remote-push alarm path** (server + APNs): the only route to the
  accessibility LED blink (§6c) and a delivery path that survives app death;
  pairs naturally with the Critical Alerts entitlement above.
- Foghorn alert-sound replacement (PM pick pending; Warfare horn placeholder).
- Second detection mode (would introduce the tab bar per DESIGN pivot note).
