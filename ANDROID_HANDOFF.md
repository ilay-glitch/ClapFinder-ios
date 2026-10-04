# ANDROID_HANDOFF.md — Guard Dog for Android

Audience: the Android developer building **Guard Dog — Don't Touch My Phone**
from scratch. This is a **rewrite, not a port** — nothing in §5 should be
translated. Everything you need is behavior (§1), assets (§2), monetization
rules (§3), and a hard warning list about what was iOS-specific (§4).

State of the iOS app at handoff (2026-10-04): both modes shipped on `main`,
pre-TestFlight QA pending (PR-P3 gate, §6). iOS identity:
`com.appcentral.guarddog`, App Store name "Guard Dog — Don't Touch Phone".

---

## 1. Product spec (platform-neutral)

### 1.1 What the app is

An anti-theft deterrent with a cartoon guard-dog mascot. The user arms a
guard; if the trigger condition fires, the phone screams a user-chosen alarm
sound until the owner disarms it on-screen. Two modes, one grammar:

| Mode | Trigger | Session posture |
|---|---|---|
| **Don't Touch** (hero mode) | phone is MOVED while lying unattended | survives screen-off/lock — must keep detecting in background |
| **Pocket Mode** | phone is PULLED OUT of a pocket | app in foreground the whole session (see §4 before assuming iOS's constraints!) |

Core rules that define the product's character:
- **Disarm is the only way out of an alarm.** No timeout, no shake-to-stop,
  no PIN (PIN is parked as a premium candidate). The alarm overlay covers
  the ENTIRE screen including any navigation chrome — nothing else is
  tappable while alarming.
- **Fail loud, never silently.** If the system kills a guard session
  (interruption, lock in pocket mode, audio loss), the app must post a
  notification: "Touch Alert stopped / The system interrupted monitoring.
  Your phone is not being watched right now." The user must never believe
  they're guarded when they aren't.
- **Modes are mutually exclusive.** Arming one disarms the other.
- **The chirp grammar (car-remote feedback).** ONE sound, both ways: a short
  double 1 kHz beep ("chirp-chirp", `arm_chirp` asset) plays when a guard
  ENGAGES and again on every disarm — like a car remote that chirps the same
  on lock and unlock. In Don't Touch it plays at the END of the grace period
  (the moment monitoring actually starts — the user has already stepped
  away); in Pocket Mode it plays when the pocket-in is confirmed (audible
  through fabric) and on disarm.

### 1.2 Don't Touch mode — behavior

```
disarmed
  → [tap hero]        grace (5 s countdown ring; motion ignored —
                      "Arming — put your phone down…")
  → [grace ends]      monitoring (chirp-chirp; "Armed — don't touch 🛡️")
  → [motion trigger]  alarming (sound loops + torch pulses + haptics,
                      full-screen overlay; "Motion detected!")
  → [DISARM tap]      disarmed (chirp)
```

- **Motion trigger**: accelerometer user-acceleration magnitude (gravity
  removed), sampled at 10 Hz. Trigger = **2 consecutive samples** above the
  sensitivity threshold (rejects single-sample sensor spikes; one
  below-threshold sample resets the count). Thresholds (g):
  Low 0.15 (deliberate pickup) · Medium 0.08 (default) · High 0.04 (nudge).
  Known open issue: High fires on table vibration — a data-collection round
  for a vibration-vs-pickup discriminator was in flight on iOS (gravity-delta
  / rotation-rate candidates). Ship the thresholds, expect to tune.
- **Disarm from any state** (grace cancel, monitoring stop, alarm stop) —
  same button, chirps every time.
- **Alarm response** = selected sound looping at full volume + flashlight
  (torch) pulsing + continuous haptics, simultaneously, until disarm.
- **Alarm notifications**: when the alarm fires, post a notification
  immediately and again at +5 s and +10 s (3 total): title "🚨 Motion
  detected!", body "Guard Dog caught someone touching your phone!". Disarm
  cancels any unfired ones AND removes delivered ones — none may fire late.
- **Backgrounding while armed**: monitoring must survive screen lock and
  backgrounding (on iOS this needed a silent-audio keep-alive — see §4.4 for
  what Android should do instead). If the session dies anyway → fail-loud
  notification + return to disarmed.
- **Lock-screen presence**: iOS shows a Live Activity while armed (status
  line "Arming — %d… / Armed — don't touch 🛡️ / Motion detected!" + a
  disarm action). Android equivalent: an **ongoing notification** with the
  live status and a disarm action — this is the natural Android pattern and
  doubles as the foreground-service notification (§4.4).

### 1.3 Pocket Mode — behavior

```
disarmed
  → [tap hero]        awaitingPocket ("Screen on — slide me into your pocket…")
  → [covered ≥ 1.5 s] monitoring (chirp through the fabric; "On duty in your pocket 👀")
  → [uncovered ≥ 0.5 s] alarming (full alarm + overlay on the relit screen;
                        "Phone pulled out!")
  → [DISARM tap]      disarmed (chirp)
```

- Sensor: proximity (ear sensor). **Debounces**: cover must be sustained
  ≥ 1.5 s to engage (rejects hand-shadow flicker while pocketing); uncover
  must be sustained ≥ 0.5 s to alarm (rejects loose-fabric flicker). A
  flicker back to the previous state clears the pending transition.
- Tap again during `awaitingPocket` cancels (chirp). No timeout.
- While ALARMING, chaos (buttons pressed, app backgrounded by the thief)
  must NOT silence the alarm.
- On iOS the whole session is foreground-only and dies loudly on lock/call —
  **do not assume that on Android**; see §4.1. Design the Android session
  posture only after the probe.
- Edge behavior, accepted: face-down on a desk also covers the sensor and
  engages ("desk pocket" — it's a feature).

### 1.4 Shared surface

- **Two tabs**: 🛡️ "Don't Touch" · 👖 "Pocket Mode". The alarm overlay sits
  ABOVE the tab bar (a reachable tab bar during an alarm is an escape hatch).
- **Guard grid** (on the Don't Touch tab, one global selection): 16 sounds,
  each an "animal/guard" card with emoji + name. The selection is the alarm
  voice for BOTH modes. The **alarm overlay shows the selected guard's emoji**
  (120 pt, bouncing) — NOT the barking-dog art (explicit PM ruling; the
  barking asset is marketing-only).
- **Sensitivity control** (Low/Medium/High) — Don't Touch tab only; Pocket
  Mode has no sensitivity concept in v1.
- **One-line model explainers** under the idle status:
  Don't Touch: "Arm it, set your phone down — any movement sets off the alarm."
  Pocket: "Arm it, slide the phone in your pocket — pulling it out sets off the alarm."
- **Volume tip card** (once, after the first completed session, dismissible):
  "🔊 Louder = safer / The alarm barks at your phone's volume — turn it up
  before you walk away. It sounds even with the ringer switch off." —
  reword the last sentence to match Android's actual audio-stream behavior
  (iOS's claim comes from its playback session bypassing the mute switch;
  verify what your chosen stream does with DND/volume before promising it).
- **Status copy** (exact strings): see §1.6.

### 1.5 Launch & onboarding story

Cold launch: **splash** (mascot, tagline "Nobody touches your phone.
Ever. 🐶🛡️", fake loading "Loading %d%%…", App Open Ad window per §3) →
**onboarding** (first launch only, 3 steps) → **home**.

Onboarding steps ("STEP %d OF 3"):
1. "I'll guard your phone!" / "Put me on watch — if anyone touches your
   phone, I bark 🐶🛡️" (waving mascot) → Continue
2. "If guarding stops, you'll know" / "I'll send a notification if anything
   interrupts my watch 🔔" → **Enable Notifications** (this is where the
   notification permission is requested — tied to the fail-loud promise,
   which is honest and converts)
3. "Ready to stand guard." / "Arm me whenever you leave your phone." → Start

Before the first-ever arm, a one-time alert explains the notification ask:
"One quick thing / Guard Dog will ask to send notifications — so we can tell
you if guarding stops. / Got it". Returning launches: splash → home.

### 1.6 Copy (source of truth — iOS `Localizable.strings`)

| Key moment | String |
|---|---|
| Home title / subtitle | "Guard Dog" / "Don't touch my phone!" |
| Grid header | "Choose your guard" |
| DT idle / grace / armed / alarm | "Tap the shield to arm" / "Arming — put your phone down…" / "Armed — don't touch 🛡️" / "Motion detected!" |
| Pocket idle / awaiting / armed / alarm | "Tap to guard your pocket" / "Screen on — slide me into your pocket…" / "On duty in your pocket 👀" / "Phone pulled out!" |
| Disarm button | "DISARM" |
| Stand-down notification | "Touch Alert stopped" / "The system interrupted monitoring. Your phone is not being watched right now." |
| Alarm notification | "🚨 Motion detected!" / "Guard Dog caught someone touching your phone!" |
| Tabs | "Don't Touch" / "Pocket Mode" |

### 1.7 Analytics events (names are the contract)

`touch_alert_armed(sensitivity)` · `touch_alert_triggered(sensitivity,
grace_elapsed_s)` · `touch_alert_disarmed(sensitivity, was_alarming,
armed_duration_s)` · `pocket_armed` · `pocket_engaged` · `pocket_alarm` ·
`pocket_disarmed(was_alarming, armed_duration_s)` · `pocket_standdown(reason)`
plus the ad events in EVENTS.md.

---

## 2. Asset manifest

### 2.1 Guard art (6 + icon) — same character everywhere

Cartoon golden-retriever puppy in a navy police cap with gold paw badge,
floppy ears (NEVER upright ears — PM rejected two generations over this),
navy collar with gold tag, carrying a blue shield with an embossed gold-rimmed
paw. Source renders 1024²–1408×768 on flat `#5BB8FF`; the two Home heroes
were cut to transparent background (use the transparent versions).

| Slot | iOS asset (in `ClapFinder/Resources/Assets.xcassets/`) | Used for |
|---|---|---|
| Hero idle | `guard_dog_shield` (standing, shield at side; **transparent bg**) | Home mascot when disarmed; onboarding step 3; splash |
| Hero armed | `guard_dog_watching` (sitting square, alert; **transparent bg**) | Home mascot while armed; Pocket tab mascot |
| Home background | `guard_dog_home_background` | full-bleed illustrated backdrop under a 30% `#5BB8FF` scrim |
| Onboarding wave | `guard_dog_wave` (waving) | onboarding step 1 |
| Alarm bark | `guard_dog_barking` | **NOT wired in-app** (PM ruling: alarm shows the selected guard's emoji) — marketing/store creatives only |
| App icon | `AppIcon` set (dog face, opaque corners) | launcher icon |

### 2.2 Sounds (17 files) + licenses

All shipped as mono 44.1 kHz (iOS uses CAF; re-encode for Android from the
source URLs below — **do not** lift the CAFs). License record:
`SOUNDS_LICENSES.md` (Mixkit License + Pixabay Content License, both free
for commercial use, no attribution required — keep the same record file in
the Android repo).

| File | Source |
|---|---|
| `siren` | Mixkit #1642 (Ambulance siren US) |
| `alarm_clock` | Mixkit #992 (Digital alarm buzzer) |
| `bell` | Mixkit #603 (Church bell calling) |
| `foghorn` | Mixkit #2289 (Warfare horn) — **placeholder, PM may swap** |
| `air_horn` | Pixabay #273892 |
| `whistle` | Pixabay #291816 (referee whistle) |
| `beep` | Pixabay #34359 (alarm beep) |
| `doorbell` | Pixabay #482879 (ding dong) |
| `dog_bark`, `cat_meow`, `cow_moo`, `frog_ribbit`, `duck_quack`, `pig_oink`, `rooster_crow`, `sheep_baa` | pre-existing synthesized assets (ship as-is) |
| `arm_chirp` | Pixabay #327691, trimmed 0.03–0.58 s to the double 1 kHz beep — the chirp grammar sound |

### 2.3 Brand palette (design tokens, hex)

| Token | Hex | Role |
|---|---|---|
| skyPrimary | `#5BB8FF` | app background, art background |
| skyTint | `#A8DCFF` | pulse-ring gradient start |
| ctaBlue | `#2D7FF9` | primary action / armed fill |
| cream | `#F5EEE0` | tip cards / callouts |
| textPrimary | `#14233D` | navy text (60% / 40% alpha for secondary/tertiary) |
| listeningActive | `#22C55E` | "armed and watching" green |

Alarm overlay: black 55% + red 32% washes over everything. Hero circle:
white when idle, ctaBlue when armed, pulse rings while monitoring.

---

## 3. Monetization spec (rules, not code)

Free app, ad-supported. **Android needs its OWN AdMob app + ad-unit IDs —
do not reuse any ID found in the iOS repo (those are Google's TEST IDs
anyway; production iOS IDs are PM-held secrets).** Formats: interstitial +
app open. **No banner** — removed by PM ruling 2026-07-12 (bottom chrome too
heavy with the tab bar; decision record in `ADS_DESIGN.md` v3).

**Interstitial (D1-v2 + D2 rules):**
- A **"use" = a completed guard session**: armed, then disarmed BY THE USER
  from the monitoring state (either mode). Grace-cancels don't count; alarm
  dismissal is NOT a use-moment.
- Presentation may be **attempted only at disarm-to-idle** — never during
  arm, grace, monitoring, alarm, or alarm-dismiss. Hard rule: **no ad of any
  kind while a guard is armed or alarming.**
- Frequency: at each counter reset, draw a threshold uniformly from **3–5**
  and persist it with the counter. Show when `uses ≥ threshold` and nothing
  is active; then reset + redraw. An ad that isn't loaded when eligible
  **preserves** the counter (retry at the next disarm).

**App Open Ad (5 hard rules):** cold launch only (never warm resume) ·
never on first-ever launch (first impressions ad-free, no disclaimer
either) · max 1 per session · ≥ 4 h since the last one (persisted
timestamp) · 5 s load timeout → go to home without it, discard late ads.
While a request is in flight the splash shows "This action can contain ads".
Consent interplay: on Android replace iOS's ATT with **UMP/consent flow**,
and it must resolve before the first possible ad request (the
no-first-launch-ad rule buys you that window).

---

## 4. CRITICAL — the "re-probe on Android" list

Everything below is something we **worked around because iOS forbids it**.
Android may not forbid it. **Do NOT import the workaround as a requirement.**
For each: run a D0-style probe — a tiny throwaway build that logs evidence
on a real device — BEFORE designing the feature around either answer. That
discipline (probe gate → design doc → build) caught three iOS platform walls
before they burned us; keep it.

| # | iOS limit (verified on-device, iOS 26) | iOS workaround | Android probe question |
|---|---|---|---|
| 4.1 | Proximity sensor is foreground-only; a locked phone = blind sensor | Pocket Mode arms unlocked/foreground; system proximity-blank keeps app active; lock = fail-loud stand-down | Android `SensorManager` proximity + a foreground service + wake lock may keep sensing **while locked**. If true, Pocket Mode works with the screen off/locked — a genuinely better product than iOS. Probe: locked-screen proximity events, with screen off, across OEMs (Samsung/Xiaomi battery killers!). |
| 4.2 | Torch is camera-subsystem, foreground-only; background torch writes silently ignored | Alarm torch only pulses in foreground; self-recovers on unlock | `CameraManager.setTorchMode` from a foreground service generally works in background on Android. Probe: torch pulsing while locked, during an alarm, on 2–3 OEMs. If green, the locked alarm gets its flash — iOS never could. |
| 4.3 | Accessibility LED/flash-blink never fires for third-party LOCAL notifications (remote push only) | Dropped the feature; copy rewritten to promise only sound | Irrelevant as such on Android — if 4.2 passes you drive the torch yourself. Don't rebuild the notification-LED dependency at all. |
| 4.4 | Background execution while armed required a **silent-audio keep-alive** (zero-volume playback loop) — fragile, interruption-prone | SilentKeepAlive + watchdog stand-down on session death | Android has a first-class answer: **foreground service** (`FOREGROUND_SERVICE`, type `specialUse`/`mediaPlayback` — check current Play policy) with an ongoing notification (which you want anyway, §1.2). No silent-audio hack. Probe: sensor delivery rates + service survival under battery optimization / Doze on major OEMs; require "ignore battery optimizations" only if the probe proves you need it. |
| 4.5 | Alarm audio vs. mute: iOS `.playback` session bypasses the ringer switch | Promised in the volume tip | Probe which Android stream (`STREAM_ALARM` is the natural choice) bypasses DND/mute and respects alarm volume, then write the tip copy to match reality. |
| 4.6 | No API to deep-link into specific Settings panes (private API = rejection) | Tips give the settings path as text | Android has real Settings intents (`ACTION_APPLICATION_DETAILS_SETTINGS`, channel settings, etc.) — use them; don't copy the text-path pattern. |

Also re-validate the two debounce values (1.5 s / 0.5 s) and the motion
thresholds on Android hardware — they were tuned against iPhone sensors.

## 5. What does NOT transfer (do not translate these)

- **All Swift/SwiftUI code.** The behavior spec above is the contract; the
  code is not.
- **SilentKeepAlive** (zero-volume AVAudioEngine loop) — an iOS-only hack;
  Android uses a foreground service (§4.4).
- **The `willPresent` delegate story** (foreground notification presentation)
  and everything downstream of it — iOS-specific notification plumbing.
- **Live Activities / ActivityKit** — replace with the ongoing notification.
- **The `@Observable` coordinator + pure-logic-struct split** is a good
  *pattern* (pure state machines with injected clocks made every debounce
  and grace rule unit-testable without sleeping — strongly recommended), but
  the types themselves (`MotionAlertLogic`, `PocketModeLogic`,
  `TouchAlertCoordinator`, `PocketModeCoordinator`, `AlarmResponder`) are
  iOS artifacts. Re-derive from §1's state machines.
- **CAF audio files, asset catalogs, xcodegen/project.yml, SwiftLint rules,
  file-based `*diag.csv` device diagnostics** (that last one exists because
  iOS device logs are unreadable without root — Android has `adb logcat`).
- The dormant clap-detection package (`ClapDetector`, `ClapSpectral`,
  calibration, SoundAnalysis investigation) — out of product scope entirely;
  it stays archived in the iOS repo only.

## 6. Open items inherited at handoff

- **Pocket Mode state**: implementation complete on `main` (PR-P1 tabs,
  PR-P2 logic/coordinator/UI, all merged). **PR-P3 — the on-device QA gate
  (Q1–Q11 in `POCKET_MODE_DESIGN.md` §6) has NOT run yet**, including the
  30-min battery measurement (Q8) and standing right-side-up pocket session
  (Q9). Whoever ships iOS runs it; Android should plan the same gate.
- **Open PRs**: none — the queue is clean as of 2026-10-04.
- **Foghorn sound**: Mixkit Warfare horn #2289 is a placeholder; PM pick of
  a true foghorn is pending (candidate links live in the chat record).
  Android should ship whatever the PM picks.
- **Critical Alerts (iOS)**: parked post-launch — an entitlement application
  so alarm notifications bypass silent/Focus. The Android analog is simply
  using the alarm stream + channel importance HIGH; fold into probe 4.5.
- **Motion-sensitivity data round**: `motiondiag.csv` logging shipped; the
  PM's labeled sessions (vibrating table vs. real pickup) and the resulting
  discriminator analysis never happened. Android inherits the open question
  (High sensitivity fires on table vibration).
- **EVENTS.md / PIVOT.md updates** for Pocket Mode were scheduled for PR-P3
  and are not yet written.
