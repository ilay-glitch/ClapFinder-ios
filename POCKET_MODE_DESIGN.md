# POCKET_MODE_DESIGN.md — Guard Dog's second mode

Status: **draft v1 for PM redline** (2026-07-12). No code until redlined.
Gate: D0 probe PASSED on-device 2026-07-12 (iPhone 15, iOS 26.5) — see §2.

## 1. Concept & story

Phone in your pocket → quiet. Someone slides it OUT → alarm. The same guard
dog, new post: **"I'll guard your pocket 👀"**. This is the second detection
mode from the winning creative's day-one tab bar and fires the tab-bar
trigger parked in PIVOT ("no tab bar at launch, add when a second mode
exists"). PM rulings 2026-07-12: tabs approved, no-PIN approved, D0-gate
sequencing approved.

## 2. Mechanism (D0-verified) and hard limits

**Foreground proximity-blank.** `UIDevice.proximityState` is foreground-only
(platform limit #3, after torch §6b and LED §6c in PIVOT.md). Pocket Mode
therefore arms with the phone UNLOCKED and the app OPEN. When the sensor
covers, the system blanks the screen (touch disabled, display off) while the
app stays **foreground-active**. Uncover → screen relights instantly, no lock
screen — the alarm overlay with DISARM is right there. Competitor precedent:
every iOS pocket-mode app works exactly this way and says so ("does not work
when the phone is locked").

D0 evidence (`pocketdiag.csv`, 2m17s session, 8 transitions, 3 orientations):

| D0 row | Result |
|---|---|
| 1. Proximity events during blank | ✅ all transitions fired; covered state held through a 51 s dark stretch |
| 2. appState during blank | ✅ `.active` in all 27 heartbeats |
| 3. Auto-lock suppressed (`isIdleTimerDisabled`) | ✅ **closed** — PM Auto-Lock is 30 s; the 51 s continuous blank stretch (and 2m17s session) survived it 1.7–4× over with zero lifecycle rows. Q7 stays as the regression row. |
| 4. CoreMotion during blank | ✅ steady 10 Hz (49–52 samples / 5 s window) |
| 5. Audio during blank | ✅ beeps audible on pocket-in and pocket-out (PM ears) + healthy session log |
| 6. Battery | ⚠️ unmeasured at 2 min resolution → QA row Q8 (30-min measurement) |
| 7. Upside-down parity | ✅ covered stable + prompt transitions at gravY +0.85…+0.97; standing right-side-up signature absent from data → QA row Q9 |

Session requirements while armed: `isProximityMonitoringEnabled = true`,
`isIdleTimerDisabled = true`, audio session `.playback` activated at arm
(instant alarm; no mic, no keep-alive needed — the app never backgrounds in a
healthy session).

**What kills a session** (all detected, all fail-loud via the §4.2 watchdog
pattern — local notification "Guard stopped watching"):
- user presses the side button (app backgrounds)
- incoming call / Siri / app switch takes foreground
- anything else that resigns active mid-session

## 3. State machine

States mirror Touch Alert's grammar (TOUCH_ALERT_DESIGN.md §3): disarm is the
only way out of the alarm.

```
disarmed
  → [tap arm]      awaitingPocket   "Screen on — slide me into your pocket"
  → [covered ≥ 1.5 s sustained]     monitoring (chirp plays — heard through fabric)
  → [uncovered ≥ 0.5 s sustained]   alarming (full alarm + overlay, screen relit)
  → [DISARM tap]                    disarmed (chirp)
```

- `awaitingPocket` → tap again to cancel (chirp). No timeout in v1: the user
  is holding an open app; nothing burns.
- The 1.5 s covered debounce rejects hand-shadow flickers while pocketing.
- The 0.5 s uncovered debounce rejects loose-fabric flicker. If field QA
  shows flicker false-alarms, the tightening lever is a motion-spike AND-gate
  (10 Hz stream already live) — data first, same discipline as the
  motion-threshold work.
- "It's me" answer (PM ruling): NO PIN, no shake-to-dismiss, no pre-alarm
  grace (a grace window is a thief's head start). The alarm is the deterrent;
  the owner taps DISARM on the screen already lit in their hand. PIN-disarm
  parked as a premium candidate.
- Interruption/background during `awaitingPocket`/`monitoring` → stand-down:
  stop session, fire "stopped watching" notification, return to `disarmed`.

## 4. UI — the tab bar arrives

Two tabs, creative parity (PM-approved):

| Tab | Content |
|---|---|
| 🛡️ **Don't Touch** | today's Home unchanged (Touch Alert hero, status, grid, sensitivity, tips, banner) |
| 👖 **Pocket Mode** | same layout skeleton: hero mascot (watching pose), arm button, status label, instruction copy |

Shared: guard grid selection (one global sound choice — lives on the Don't
Touch tab in v1), chirp grammar, AlarmResponder, alarm overlay, ads policy
(banner idle-only on both tabs; interstitial "use" definition D1-v2 extends to
completed pocket sessions — same user-disarm-from-monitoring rule).
NOT shared: sensitivity (motion-only concept; hidden on the Pocket tab in v1).

Status copy (Localizable keys `pocket.status.*`):
- disarmed: "Tap to guard your pocket"
- awaitingPocket: "Screen on — slide me into your pocket…"
- monitoring: "On duty in your pocket 👀"
- alarming: "Phone pulled out!"

Onboarding: unchanged in v1 (Touch Alert remains the hero flow). A one-line
"NEW: Pocket Mode" ribbon on the tab is enough discovery.

## 5. Architecture

`PocketModeCoordinator` in `ClapFinderKitMotion`, sibling of
`TouchAlertCoordinator`, owning the same `AlarmResponder` instance (single
response pipeline; the two coordinators are mutually exclusive — arming one
disarms the other; enforced in the coordinator layer, unit-tested).
Pure state machine extracted as `PocketModeLogic` (no UIKit) for tests, same
split as `TouchAlertLogic`. Proximity + idle-timer calls live behind
`#if canImport(UIKit)` in the coordinator.

Analytics (EVENTS.md additions): `pocket_armed`, `pocket_engaged` (covered →
monitoring), `pocket_alarm`, `pocket_disarmed(duration, wasAlarming)`,
`pocket_standdown(reason)`.

## 6. QA gate (extends PRE_TESTFLIGHT_QA)

| # | Case | Expected |
|---|---|---|
| Q1 | Arm → pocket-in | blank + chirp at ≥1.5 s covered; no alarm from pocketing motion |
| Q2 | Pull out while monitoring | alarm ≤ 1 s after sustained uncover; overlay + DISARM on relit screen |
| Q3 | Disarm from alarm | alarm stops, chirp, back to disarmed |
| Q4 | Side-button lock while monitoring | stand-down notification fires; no silent death |
| Q5 | Incoming call while monitoring | stand-down notification fires |
| Q6 | Loose-pocket flicker (walk, sit, stairs) | no false alarm (debounce holds) |
| Q7 | Auto-Lock = 30 s setting, 5-min pocketed session | session survives (idle timer disabled) — closes D0 row 3 unconditionally |
| Q8 | 30-min pocketed session | battery Δ recorded — closes D0 row 6 |
| Q9 | Full session upside-down/head-first AND right-side-up standing | identical behavior — closes D0 row 7 footnote |
| Q10 | Face-down on desk arming | covered = engages ("desk pocket" — accepted behavior, documented) |
| Q11 | Mutual exclusivity | arming Pocket disarms Touch Alert and vice versa |

## 7. Out of scope (parked)

- PIN-disarm (premium candidate, PM ruling)
- Bag mode marketing angle (same mechanism, copy-only — revisit at ASO)
- Locked-phone pocket detection (platform-impossible, §2)
- Third mode / Clap-to-Find revival (would reopen the dormant package)

## 8. Implementation plan (after redline)

1. **PR-P1** — tab scaffold: TabView, Touch Alert screen moves intact, empty
   Pocket tab behind it. Zero behavior change, screenshot-diff QA.
2. **PR-P2** — `PocketModeLogic` (pure, tested: debounce timing, state
   transitions, mutual exclusivity) + `PocketModeCoordinator` + Pocket tab UI
   + strings. D0 probe code retired in the same PR (served its purpose).
3. **PR-P3** — QA gate run (Q1–Q11 on device, PM), EVENTS.md + PIVOT.md
   updates, then merge queue.
