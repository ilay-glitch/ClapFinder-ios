# Migration / Hardware Validation Log

Hardware-dependent checks that cannot be verified in the simulator.
Every Phase-1-closing device QA pass adds one block below. A PR that
requires device QA must not merge until its block is filled in.

Result values: ✅ pass / ❌ fail (link issue) / ⏳ not yet run

> **Gate status (2026-06-11, PM ruling — supersedes the two-stop gate):**
> Implementation is ungated; everything builds first, QA happens once at
> the end. **TestFlight requires all four:**
> 1. All QA blocks below filled in ONE consolidated device pass —
>    PR-9 block, PR-10 block, and the touch-alert block including
>    threshold calibration.
> 2. Real audio for the 8 alert sounds (siren, alarm_clock, air_horn,
>    bell, whistle, beep, doorbell, foghorn) — currently generated
>    synthesized placeholders. The 8 animals are real Boomr audio.
>    (The earlier 8 synthesized *animal* stand-ins were removed in PR-14.)
> 3. Production AdMob IDs (app ID + ad unit ID — placeholders are
>    marked in Info.plist and AppOpenAdLoader).
> 4. Final app icon (current icon is a solid-color placeholder).
>
> **Post-QA condition for PR-13/14 (Firebase+Adjust, Remote Config):**
> cleared to land after the consolidated pass — UNLESS either touches
> the ATT prompt code path (requesting, not just reading status), in
> which case the ATT QA rows below re-run on device before TestFlight.

---

## Device QA pass — Phase 1 close (PR-9)

| Field | Value |
|---|---|
| Date | ⏳ |
| Tester | ⏳ |
| Device model | ⏳ (e.g. iPhone 15 Pro) |
| iOS version | ⏳ (e.g. iOS 26.4) |
| Build | ⏳ (commit SHA or TestFlight build #) |

| # | Check | Steps | Result | Notes |
|---|---|---|---|---|
| 1 | Clap detection — sensitivity **Low** (−30 dBFS) | Set Low, start listening, double-clap loudly at ~1 m | ⏳ | |
| 2 | Clap detection — sensitivity **Medium** (−40 dBFS) | Set Medium, start listening, double-clap at normal volume at ~2 m | ⏳ | |
| 3 | Clap detection — sensitivity **High** (−50 dBFS) | Set High, start listening, double-clap softly at ~3 m | ⏳ | |
| 4 | Flashlight pulse | Trigger detection, verify torch pulses 3× (150 ms on / 100 ms off) | ⏳ | |
| 5 | Max-volume playback | Trigger detection, verify animal sound plays at full volume regardless of volume slider | ⏳ | |
| 6 | Silent-switch override | Flip ringer switch to silent, trigger detection, verify sound still plays | ⏳ | |

### Out of scope for this pass (tracked in PLAN.md Phase 1 close)
- Background clap detection (screen off, 10+ min)
- ATT prompt first-launch flow
- Mic permission prompt copy

### Simulator coverage (already done — 2026-06-10)
UI rendering only: home screen layout, animal grid, mic toggle, status
label verified on iPhone 17 Pro simulator (iOS 26.4). Microphone,
flashlight, and silent-switch behavior **cannot** be tested in the
simulator.

---

## Device QA pass — PR-10 splash + App Open Ad

| Field | Value |
|---|---|
| Date | ⏳ |
| Tester | ⏳ |
| Device model | ⏳ |
| iOS version | ⏳ |
| Build | ⏳ |

| # | Check | Steps | Result | Notes |
|---|---|---|---|---|
| 1 | Real ad load + present | Second+ launch (not fresh install), online: splash shows disclaimer, test ad presents, dismiss lands on Home | ⏳ | Test ad unit — Google's demo creative |
| 2 | Timeout path | Airplane mode, cold launch: splash exits to Home at ≤5 s, no ad, no hang | ⏳ | |
| 3 | First-launch path | Fresh install (delete app first): splash shows NO disclaimer, no ad, lands on Home | ⏳ | |
| 4 | Frequency cap | Two cold launches within 4 h (after an ad showed): second launch shows no ad | ⏳ | |
| 5 | Background mid-splash | Background during splash, return: no restart, no double ad request | ⏳ | |
| 6 | ATT prompt after splash | Fresh install: ATT prompt appears only AFTER the splash completes and Home is visible — never over the splash | ⏳ | |

### Simulator coverage (2026-06-11)
Fresh install verified: splash scene renders per mockup, no disclaimer on
first launch, hands off to Home. Second launch verified: disclaimer
appears, test ad request fires. Real ad presentation, timeout, and
frequency-cap timing require device QA.

---

## Device QA pass — PR-11 Touch/Motion Alert

| Field | Value |
|---|---|
| Date | ⏳ |
| Tester | ⏳ |
| Device model | ⏳ |
| iOS version | ⏳ |
| Build | ⏳ |

| # | Check | Steps | Result | Notes |
|---|---|---|---|---|
| 1 | Pickup detection — Low | Arm at Low, phone flat on table, wait out grace, pick up deliberately | ⏳ | |
| 2 | Pickup detection — Medium | Arm at Medium, slide phone across table | ⏳ | |
| 3 | Pickup detection — High | Arm at High, nudge the table | ⏳ | |
| 4 | Grace period | Arm, put phone down within 5 s — no alarm; move at 6 s — alarm | ⏳ | |
| 5 | Screen-locked detection | Arm → lock screen → move phone → alarm fires | ⏳ | |
| 6 | Alarm audio | Alarm at max volume with silent switch ON; loops until disarm | ⏳ | |
| 7 | Disarm | Disarm stops sound + flashlight immediately; re-arm works | ⏳ | |
| 8 | Interruption | Incoming call while armed → "monitoring stopped" notification | ⏳ | |
| 9 | Mode exclusivity | Arming Touch stops clap listening and vice versa | ⏳ | |
| 10 | **Threshold calibration** | At each sensitivity, record the minimum action that triggers (nudge / slide / pickup); adjust constants — calibrated values become shipped defaults | ⏳ | |
| 11 | Battery soak | Overnight armed, report % drain | ⏳ | |

---

## Device QA pass — PR-12 Banner + Interstitial

| # | Check | Steps | Result | Notes |
|---|---|---|---|---|
| 1 | Banner idle-only | Banner shows at Home bottom when idle; disappears while listening AND while armed | ⏳ | |
| 2 | Interstitial frequency | Start+stop listening repeatedly: interstitial appears after 3–5 stops, then not again until another 3–5 | ⏳ | |
| 3 | Never during detection | No interstitial appears while listening or mid-alarm; none on arm/disarm | ⏳ | |
| 4 | Dismiss path | Interstitial dismiss returns to Home with detection off, app responsive | ⏳ | |
| 5 | Counter persistence | Force-quit between uses: counter survives relaunch | ⏳ | |

---

## Device QA pass — PR-13 Touch-Alert Live Activity

⚠️ Live Activities render only on a real device's Lock Screen / Dynamic
Island — not exercisable in the simulator. **Also verifies the free-account
extension constraint** (LIVE_ACTIVITY_DESIGN.md §5.1): if the widget
extension fails to sign/install on the personal team, fall back to the
notification-action button.

| # | Check | Steps | Result | Notes |
|---|---|---|---|---|
| 1 | Extension installs | App + widget extension install on device with the personal team | ⏳ | Free-account App-ID limit check |
| 2 | Activity appears on arm | Arm shield → Live Activity card shows on Lock Screen + Dynamic Island | ⏳ | |
| 3 | Reflects state | Card shows grace countdown → "Armed" → "Motion detected!" on trigger | ⏳ | |
| 4 | Disarm from Lock Screen | Tap Disarm on the Lock Screen card → sound + flash + vibration all stop | ⏳ | The core feature |
| 5 | Disarm from Dynamic Island | Expand island → Disarm → alarm stops | ⏳ | |
| 6 | Activity ends | In-app disarm also removes the Live Activity | ⏳ | |

---

## Device QA pass — PR-14 real-world alert sounds

| # | Check | Steps | Result | Notes |
|---|---|---|---|---|
| 1 | All 8 alerts play (clap) | Select each: siren, alarm_clock, air_horn, bell, whistle, beep, doorbell, foghorn → clap → plays at full volume | ⏳ | |
| 2 | All 8 alerts play (touch) | Arm touch alert on each alert sound → trigger → alarm loops the sound | ⏳ | |
| 3 | Silent-switch override | Ringer off → trigger → alert still plays | ⏳ | |
| 4 | Siren is default | Fresh install → siren is the pre-selected sound | ⏳ | |
| 5 | Grid layout | 4×4, no clipping, animals + alerts both legible | ⏳ | |

---

## Device QA pass — PR-15 clap recognition (SoundAnalysis)

⚠️ Real recognition accuracy is device-only (no mic in simulator).

| # | Check | Steps | Result | Notes |
|---|---|---|---|---|
| 1 | Clap fires (near) | Listen → double-clap at ~1 m → animal/alert plays | ⏳ | |
| 2 | Clap fires (distant) | Double-clap at ~3–5 m → fires (raise sensitivity if needed) | ⏳ | |
| 3 | Speech does NOT fire | Talk loudly near the phone while listening → no trigger | ⏳ | The whole point |
| 4 | Door/bang does NOT fire | Slam a door / knock → no trigger | ⏳ | |
| 5 | Sensitivity affects reach | Low needs a clear close clap; High catches softer/distant | ⏳ | Tune 0.75/0.55/0.40 |
| 6 | Latency acceptable | Time from double-clap to response feels responsive (<~1.5 s) | ⏳ | SoundAnalysis window |
| 7 | Battery | A few minutes of continuous listening — note drain | ⏳ | Pre-gate if excessive |
