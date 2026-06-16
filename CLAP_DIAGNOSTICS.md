# CLAP_DIAGNOSTICS.md — Clap-detection diagnostics (measure-first)

**Version:** v2 (shape note redlined + approved)
**PR:** logical PR-17 `phase2/pr-17-clap-diagnostics` (branches off `main`)
**Status:** Approved to implement. Instrumentation ONLY — no detection-logic
change, distant-clap reach untouched.

---

## 0. Why this PR exists

Clap detection over-triggers on non-claps (door knocks, single taps, speech,
music/TV). This is a **specificity** problem, not a sensitivity one. Detection
has been reimplemented three times by guessing at the algorithm; this PR
**measures the real feature-space separation between claps and non-claps on
the device first**, so the next change is made once, from data.

`#28` (energy+crest **+** calibration) is merged to `main` — main is the live
detector, so this branches off `main`.

## 1. Why SoundAnalysis was reverted (and why we're holding it for round two)

PR-15 used Apple SoundAnalysis (YAMNet `.version1`, `clapping`/`applause`
labels). On-device its **per-clap confidence was low and inconsistent
(~0.4–0.7, frequent misses)** with **~1 s analysis windows** (latency).
Research found YAMNet is the same model behind the recommended MediaPipe path
(no framework swap helps) and endorsed a DSP onset/amplitude approach → the
energy+crest detector now live.

**The catch this PR is built to expose:** crest factor measures
*impulsiveness*, not *timbre*. A knock or single tap is **also a sharp
transient → also high crest**, so it can sit directly on top of a clap in
crest/energy space. That is the most likely false-positive mechanism, and it
is exactly the **spectral discrimination** SoundAnalysis offered and crest
cannot. If the labeled data shows claps and non-claps overlap in the temporal
features, the round-two answer is likely a **hybrid** (crest onset gate → a
lightweight spectral confirm), NOT a blind re-revert to full SoundAnalysis.
That is a design decision for *after* the data — not this PR.

## 2. What gets logged

A **candidate** = any buffer **above the −55 dBFS silence floor** (claps,
knocks, taps, speech, music all clear it). Near-silence buffers are counted,
not logged line-by-line, to keep Console readable.

Per candidate, one CSV line (header printed once per session):

| field | source | meaning |
|---|---|---|
| `seq` | counter | line number within the session |
| `rms` | existing | linear RMS amplitude |
| `peak` | existing | linear peak amplitude |
| `dBFS` | existing | loudness (`20·log10 rms`) |
| `crest` | existing | `peak ÷ rms` — the current discriminator |
| `attackMs` | **new** | onset-sample → peak-sample within the buffer, sample-resolution |
| `decayDbPerMs` | **new** | dB fall from peak to buffer end (per ms) — within-buffer envelope |
| `peakAtEdge` | **new** | `1` if the peak sample sits in the first/last 8 % of the buffer → the transient straddled a boundary and `attackMs`/`decay` are truncated. **Don't over-read those rows.** |
| `threshold` | `currentCrestThreshold` | crest threshold actually in effect |
| `calibrated` | bool | calibrated value vs sensitivity-derived |
| `sens` | enum | Low / Medium / High |
| `gate` | **new** | which branch decided this buffer (below) |
| `dtMs` | existing (`delta`) | gap since the first clap, when mid-pair |

**`gate` values** (emitted on the *actual* branch the live FSM took — no
duplicated decision logic):
`belowFloor` · `lowCrest` · `firstClap` · `staleWindow` · `tooClose` ·
`noRelease` · `ACCEPT`

### §2 resolution decision (redline)
The decision-path tap stays **production-identical at 1024 frames** (~21–23 ms,
~43–48 buffers/s). Raising the tap rate was rejected: crest/RMS are computed
per buffer and feed the gates, so a smaller buffer changes the very features we
measure — contaminating the comparison with production and touching
distant-clap reach. Instead `attackMs`/`decayDbPerMs` are measured from the
**sample envelope inside each buffer** (sample-resolution), with `peakAtEdge`
marking the rows where a boundary-straddle makes them unreliable.

## 3. Debug-flag mechanism (nothing ships)

- All diagnostics live under **`#if DEBUG`** → physically absent from
  Release / App Store builds. (Debug builds are installed on-device via
  `devicectl`, so it's live for the QA session.)
- Runtime toggle `ClapDiagnostics.isEnabled` (default `true` in DEBUG) to flip
  it off mid-session without recompiling.
- **Zero impact on the accept/reject path:** `processSample`'s control flow is
  byte-for-byte unchanged; diagnostics read the same values and emit alongside
  each branch. The only added audio-thread work is one `vDSP_maxmgvi` (peak
  index) + a short envelope scan; emission happens on the MainActor, where
  logging already happens today.

## 4. How the build is read off-device

- Dedicated OSLog: subsystem `com.appcentral.clapfinder`, category
  **`ClapDiagnostics`**.
- **Console.app filter string:**
  `subsystem:com.appcentral.clapfinder category:ClapDiagnostics`
- Logged at **`.notice`** so Console captures it for an attached device
  without enabling "Include Info/Debug Messages". A CSV header line is emitted
  at listen-start; select-all → copy (or File → Export) and hand back.

## 5. Tests (pure-logic, CLI)

- `ClapDiagnostics.csvLine(_:)` + `csvHeader` — exact formatting.
- `ClapDiagnostics.transientShape(samples:sampleRate:)` — synthetic sharp
  transient → small `attackMs`, positive `decayDbPerMs` (a fall after the
  peak); `peakAtEdge` true when the peak is at a boundary.
- Gate labelling — driven through the real `processSample` via a test-only
  `@_spi(Testing)` diagnostic hook, so labels are verified against the actual
  FSM branches (not a parallel re-implementation).

The existing `ClapDetectorTests` behaviour suite is unchanged and must stay
green — that is the proof the decision path didn't move.

## 6. Out of scope (the fence)

No threshold changes, no algorithm change, no SoundAnalysis re-revert. After
the labeled session we have **one** numbers-grounded design conversation, then
change once.
