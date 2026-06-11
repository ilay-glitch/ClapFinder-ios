# Migration / Hardware Validation Log

Hardware-dependent checks that cannot be verified in the simulator.
Every Phase-1-closing device QA pass adds one block below. A PR that
requires device QA must not merge until its block is filled in.

Result values: ✅ pass / ❌ fail (link issue) / ⏳ not yet run

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
