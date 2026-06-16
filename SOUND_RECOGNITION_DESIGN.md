# SOUND_RECOGNITION_DESIGN.md — Clap detection

**Version:** v2 — energy + crest-factor DSP (SoundAnalysis approach reverted)
**PR:** logical PR-16 `phase2/pr-16-clap-energy-detection`
**Goal:** Detect a double-clap from across a room **and** distinguish it from
other loud sounds (speech, doors), reliably and with low latency.

---

## 1. Why not the ML classifier (SoundAnalysis / YAMNet)

PR-15 used Apple's on-device SoundAnalysis built-in classifier (`.version1`,
YAMNet) keyed on the `clapping` / `applause` labels. On-device testing showed
its **per-clap confidence is low and inconsistent** (a clear clap classified
at ~0.4–0.7, often missing), and its ~1 s analysis windows add latency. A
short competitor-research pass confirmed YAMNet is the same model behind the
recommended MediaPipe path, so switching frameworks wouldn't fix it. The
research equally endorsed a **DSP onset/amplitude + pattern** approach (à la
TarsosDSP / aubio / detect_clap_sound_flutter) — which is what this PR uses.

## 2. Approach — energy + crest factor

The AVAudioEngine tap yields, per ~23 ms buffer:
- **energy** (dBFS) — loudness
- **crest factor** (peak ÷ RMS) — *impulsiveness*

A **clap peak** = above a fixed silence floor (−55 dBFS) **and** crest >
threshold. Crest is the discriminator and — critically — it's **distance-
stable**: a real clap measures crest ~3.3+ near or far, while loudness falls
off with distance. So loudness only rejects silence; crest identifies claps.

A **double-clap** = two clap peaks with a non-impulsive "release" buffer
between them, ≥ `minClapGapSeconds` (0.08 s) apart, within `clapWindowSeconds`
(0.5 s), then a `cooldownSeconds` (1 s) lockout. A sustained/flat loud sound
(speech) never produces peaks (low crest); a single bang produces only one.

**Sensitivity → crest threshold** (distance-stable, calibrated on device):
| Level | Min crest | For |
|---|---|---|
| Low | 3.5 | sharp / close claps |
| Medium | 2.8 | default — room distance |
| High | 2.2 | soft / far claps |

## 3. Why not temporal smoothing

Smoothing the signal across windows (a classifier-confidence technique) would
**smear the clap impulse** and cause misses — wrong for onset detection. The
DSP robustness tools that *do* apply are all present: crest peak detection,
minimum inter-clap gap, refractory cooldown, and the double-clap FSM.

## 4. Testing

- Unit (CLI): peak = floor + crest gate; release = non-peak; double-clap
  timing (gap / window / release); crest sensitivity (Low rejects a crest-3.0
  clap, High accepts it); silence floor; cooldown.
- Device QA: clap near and far fires; speech / door does not; sensitivity
  changes reach; calibrate the crest thresholds.

## 5. Future option (if QA shows it's needed)

A one-time **clap calibration** (user double-claps once; record their actual
crest and set the threshold per device/user) is the robust next step — the
research's "device-specific calibration." Not built yet; sensitivity levels
cover it for now.
