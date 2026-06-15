# TOUCH_ALERT_DESIGN.md — Don't-Touch-My-Phone (Touch/Motion Alert)

**Version:** v2 (PM rulings folded — approved for implementation after the PR-10 QA pass)
**PR:** logical PR-11 (banner/interstitial shifts to PR-12 — core-feature
completeness before the second ad layer)
**Status:** Approved 2026-06-11. Ruling log: D1 = (a) segmented switcher;
D2 = plain disarm v1, Face ID is a v2 candidate; notification permission
on first arm with pre-permission copy; thresholds ship as defaults with
QA calibration; App Review risk accepted knowingly with mitigation noted.

---

## 1. Purpose

A second detection mode alongside clap detection: arm the phone, and
any motion above threshold triggers the alarm (selected animal sound
looped at max volume + flashlight pulses) until the user disarms it
in the app. Anti-theft / nosy-sibling use case.

**Onboarding note:** no onboarding flow exists in this codebase —
onboarding is its own future PR. When it lands, its touch-alert copy
must match §3's behavior. Until then this feature ships discoverable
from Home only.

---

## 2. Decision points (RESOLVED — PM rulings 2026-06-11)

### D1 — Home-screen surface: (a) segmented control vs (b) separate screen

| | (a) Mode switcher on Home | (b) Separate tab/screen |
|---|---|---|
| Navigation | Zero added nav — one screen stays one screen | Adds first navigation construct to the app |
| Shared controls | Animal grid + sensitivity reused in place | Must duplicate or move shared controls |
| Discoverability | High — visible on first screen | Requires the user to find it |
| Layout risk | Hero area swaps (mic toggle ↔ arm button); minor crowding | Clean separation, room for shield animation |

**RULING: (a) approved** — a segmented Clap / Touch mode switcher under
the header. Both modes share the animal catalog, the sensitivity
control, and the response pipeline; splitting screens duplicates
three-quarters of the UI to separate one control. The hero area swaps
between the mic toggle and the arm/disarm button by mode.

### D2 — Disarm security: plain disarm vs Face ID / passcode gate

**RULING: plain disarm approved for v1; Face ID noted as a v2
candidate, not implemented.** Rationale: the alarm's job
(drawing attention) is done by the time anyone reaches the disarm
button; a thief silencing the alarm has already been spotlighted.
A Face ID gate adds `LocalAuthentication` failure/lockout edge cases
(failed biometrics while an alarm blares is a hostile UX) for marginal
deterrence.

---

## 3. Behavior spec

| Rule | Value |
|---|---|
| Arm | Big arm button (hero area, Touch mode). Arming starts a **5 s grace period** — countdown shown, no detection, lets the user put the phone down. |
| Detect | After grace: device-motion magnitude above the sensitivity threshold (§5) → trigger. |
| Alarm | Selected animal sound **looped** at volume 1.0 (silent-switch override via the existing `.playAndRecord` session) + flashlight pulsing continuously + **continuous device vibration** (full-motor buzz on a repeating loop, like a ringing phone). Screen shows a full-screen alarm state. All three stop on disarm. |
| Stop | **Only** the in-app disarm button stops the alarm (D2: no auth gate in v1). Disarming also stops detection. |
| Re-arm | Manual — no auto re-arm after an alarm in v1. |
| Sensitivity | Reuses the existing Low / Medium / High control; thresholds in §5. |
| Modes are exclusive | Arming Touch mode stops clap listening and vice versa — one detection mode active at a time (one audio session owner, no double alarms). |

### Ads (hard constraints, restated from the operating contract)
- NO ad of any kind while armed or while the alarm is sounding.
- NO interstitial on arm or disarm actions.
- The App Open Ad splash path is unaffected (cold launch only — the
  app cannot be armed during cold launch).

---

## 4. Background-mode reality (researched, not hand-waved)

**The constraint:** Core Motion delivers accelerometer / device-motion
updates only while the process is executing. When iOS suspends the
app, motion callbacks stop. **There is no `UIBackgroundModes` value
for motion** — the valid values (audio, location, voip, processing,
etc.) contain nothing CoreMotion-related.

Sources:
- `UIBackgroundModes` valid values: developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes (no motion entry)
- CMMotionManager: developer.apple.com/documentation/coremotion/cmmotionmanager (updates require an executing process)

**What this means for ClapFinder, honestly stated:**

1. ClapFinder already declares `UIBackgroundModes = ["audio"]` and
   runs an active `.playAndRecord` AVAudioSession while detecting.
   While that session keeps the process executing, CoreMotion
   callbacks keep flowing — **armed touch-alert works with the screen
   locked or the app backgrounded as long as the audio session stays
   active.** Implementation: arming starts the same AVAudioEngine
   input-tap session the clap detector uses (the mic tap is the
   keep-alive; its buffers are simply not fed to clap detection in
   Touch mode).
2. If iOS tears the session down (phone call it can't resume from,
   Siri conflict, resource pressure) the process suspends and
   **detection silently stops**. Mitigation: the same interruption
   observers ClapDetector already uses; on an unresumable
   interruption while armed, fire a local notification ("Touch Alert
   was disarmed by the system") so the user isn't falsely confident.
   (**Ruling:** local-notification permission is requested on **first
   arm**, never at launch, behind a pre-permission explainer whose
   copy states why: "so we can tell you if monitoring stops.")
3. **App Review risk (flagged):** background audio must be used for
   genuinely audible/recording purposes. ClapFinder's armed state
   keeps the mic session live and can emit an alarm at any moment —
   same justification profile as clap detection, but the reviewer
   may probe why an accelerometer feature holds an audio session.
   **Mitigation:** the feature's response IS audio output — the
   alarm — which is the legitimate basis for the session; this plus
   the shared detection infrastructure goes in the App Review notes
   at submission. **Risk accepted knowingly (PM, 2026-06-11).**

**Stated limitation for the doc and store listing:** if the system
kills or suspends the app, touch alert stops. We do not promise
detection survives force-quit, and we never will.

---

## 5. Detection algorithm + battery justification

- Source: `CMMotionManager.deviceMotionUpdates` — `userAcceleration`
  (gravity already removed by Core Motion's sensor fusion), magnitude
  `√(x²+y²+z²)` in g.
- **Polling: 10 Hz** (`deviceMotionUpdateInterval = 0.1`).
  Justification: a pickup/slide event produces sustained acceleration
  over 200–500 ms, so 10 Hz samples it 2–5×; doubling to 20 Hz halves
  the detection latency margin we don't need and costs battery.
  At 10 Hz with the sensor-fusion pipeline already powered (the audio
  session dominates power draw anyway), incremental drain is
  negligible versus the already-running mic tap. Threshold check is
  O(1) per sample — no buffering, no FFT.
- Trigger rule: **2 consecutive samples above threshold** → alarm
  (rejects single-sample sensor spikes; adds ≤200 ms latency).
- Grace period: timestamps compared against an injected clock
  (same seam pattern as `AppOpenAdPolicy` — no `Date()` in logic,
  no sleeping tests).

Thresholds — **ruling: these ship as the defaults**; final
calibration happens in the device QA pass (see §9 calibration row):

| Sensitivity | userAcceleration magnitude |
|---|---|
| Low | > 0.15 g (deliberate pickup) |
| Medium | > 0.08 g (default) |
| High | > 0.04 g (nudge / table bump) |

---

## 6. Architecture (reuse, don't duplicate)

**Current coupling:** `ResponseCoordinator` owns `ClapDetector` and a
private `respond(to:bundle:)` that drives `SoundPlayer` +
`FlashlightController` as a one-shot. The response side must be
extracted, not copied — and the alarm needs a *looping* mode the
one-shot path doesn't have.

Proposed shape (the `AlertTrigger` extraction the prompt asks for):

| Unit | Module | Responsibility |
|---|---|---|
| `AlarmResponder` | `ClapFinderKitAudio` | Extracted from `ResponseCoordinator.respond`. Owns `SoundPlayer` + `FlashlightController`. Two entry points: `respondOnce(animal:bundle:)` (clap — current behavior) and `startAlarm(animal:bundle:)` / `stopAlarm()` (loop sound `numberOfLoops = -1`, repeating flashlight task). |
| `ResponseCoordinator` | `ClapFinderKitAudio` | Unchanged API; delegates its respond path to `AlarmResponder.respondOnce`. |
| `MotionDetector` | **new module `ClapFinderKitMotion`** (deps: `ClapFinderKitData`) | Mirrors `ClapDetector`'s isolation: pure threshold + grace + 2-sample state machine (`MotionAlertLogic`, clock-injected, CLI-testable) + thin `CMMotionManager` wrapper behind `#if canImport(CoreMotion)`. |
| `TouchAlertCoordinator` | `ClapFinderKitMotion` | Wires `MotionDetector` → `AlarmResponder.startAlarm`. Owns armed/grace/alarming state (`@Observable`). Starts the keep-alive audio session on arm (§4.1). |
| `TouchAlertView` + arm button + mode switcher | App target | UI per §7. |

Module dependency addition: `ClapFinderKitMotion → ClapFinderKitData`,
`ClapFinderKitMotion → ClapFinderKitAudio` (for `AlarmResponder` +
session management), and `ClapFinderKitMotion → ClapFinderKitAds`
(for `AnalyticsClient` — **acknowledged debt, not a pattern**: the
analytics protocol extracts to its own module in the Firebase PR,
which removes this edge). No circular deps introduced.

---

## 7. UI (assumes D1 = option a)

- Segmented mode switcher (Clap 👏 / Touch 🛡️) under the header,
  styled like the sensitivity control (gradient active fill).
- Touch mode hero: 72 pt arm button replacing the mic toggle —
  shield SF Symbol, `CFGradient.brand` fill when armed.
- Grace period: 5→0 countdown ring around the button.
- Armed idle: slow "watching" pulse (reuses `PulseRingsView`),
  status label "Armed — don't touch 🛡️".
- Alarming: full-screen red-tinted overlay, bouncing animal emoji,
  giant DISARM button. All strings via `Localizable.strings`.
- Reduce Motion: static armed state, no pulse; countdown as text.
- New tokens needed: none anticipated — brand gradient + existing
  status colors cover it (flag if implementation finds otherwise).

---

## 8. Analytics (EVENTS.md addition, doc commit first in the impl PR)

| Event | Params |
|---|---|
| `touch_alert_armed` | `sensitivity: String` |
| `touch_alert_triggered` | `sensitivity: String`, `grace_elapsed_s: Int` (time since arm) |
| `touch_alert_disarmed` | `sensitivity: String`, `was_alarming: Bool`, `armed_duration_s: Int` |

Transport: existing `AnalyticsClient` (OSLog now, Firebase later).

---

## 9. Testing

**Unit (CLI-runnable, clock-injected — no sleeps):**
- Grace period: sample at t+4.9 s ignored, t+5.1 s eligible.
- Threshold × sensitivity matrix (boundary above/below each level).
- 2-consecutive-samples rule: spike-spike-quiet fires; spike-quiet-spike doesn't.
- Arm/disarm transitions: disarm during grace, disarm while alarming,
  re-arm after alarm; armed-while-clap-listening exclusivity.
- Alarm loop state: `startAlarm` idempotence, `stopAlarm` always wins.

**Device QA (MIGRATION_VALIDATION.md block, gates merge):**
- Real pickup detection at all 3 sensitivities (phone flat on table).
- Screen-locked detection (armed → lock → move → alarm fires).
- Alarm audio at max volume with silent switch on.
- Interruption: incoming call while armed → local notification path.
- Battery: overnight armed soak, report % drain.
- **Threshold calibration:** at each sensitivity, record the minimum
  real-world action that triggers (nudge / slide / pickup) and adjust
  the §5 constants; calibrated values become the shipped defaults.

---

## 10. Out of scope (v1)

- Face ID / passcode disarm gate (D2 ruling: v2 candidate, not in v1).
- Auto re-arm, scheduled arming, Apple Watch companion.
- Warm-resume protection promises (process-death limitation stands).
- Onboarding screen (separate PR; copy must match §3 when it lands).

## 11. Files + diff estimate

| File | Change | ~LOC |
|---|---|---|
| `TOUCH_ALERT_DESIGN.md` + `EVENTS.md` + `DESIGN.md` (if tokens) + `PLAN.md` | docs commit | 80 |
| `ClapFinderKit/Package.swift` | new `ClapFinderKitMotion` target | 10 |
| `ClapFinderKitAudio/AlarmResponder.swift` | new (extracted + loop mode) | 120 |
| `ClapFinderKitAudio/ResponseCoordinator.swift` | delegate to responder | −30/+15 |
| `ClapFinderKitMotion/MotionAlertLogic.swift` | new — pure state machine | 140 |
| `ClapFinderKitMotion/MotionDetector.swift` | new — CMMotionManager wrapper | 110 |
| `ClapFinderKitMotion/TouchAlertCoordinator.swift` | new | 130 |
| App target: mode switcher, `TouchAlertView`, arm button, alarm overlay | new + HomeView edits | 350 |
| `Localizable.strings` | ~12 strings | 15 |
| Tests (logic + coordinator) | new | 250 |
| `MIGRATION_VALIDATION.md` | QA block | 20 |

**Total ≈ 1,200 LOC across ~14 files.** Commit order: `docs:` →
`code:` AlarmResponder extraction (pure refactor, tests stay green) →
`code:`+`tests:` motion logic → `code:` UI → `docs:` QA block.

## 12. Ruling log (v1 → v2, PM 2026-06-11)

All v1 open items resolved: D1 = (a); D2 = plain disarm (Face ID v2
candidate); PLAN.md insertion = logical PR-11, banner/interstitial →
PR-12 (core-feature completeness before the second ad layer);
notification permission on first arm with pre-permission copy;
thresholds ship as defaults pending QA calibration. Implementation
starts only after the PR-10 device QA pass clears the stack.
