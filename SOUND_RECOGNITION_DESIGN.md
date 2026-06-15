# SOUND_RECOGNITION_DESIGN.md — Real clap recognition (SoundAnalysis)

**Version:** v1 — PM delegated decisions ("do what's best") 2026-06-15
**PR:** logical PR-15 `phase2/pr-15-clap-recognition`
**Goal:** Detect claps from a distance **and** distinguish a clap from other
loud sounds (door, speech, cough). Pure energy thresholding can't do both;
Apple's on-device sound classifier judges *identity*, not just loudness.

---

## 1. Approach

Feed the existing AVAudioEngine input tap into Apple's **SoundAnalysis**
built-in classifier (`SNAudioStreamAnalyzer` + `SNClassifySoundRequest`
with `classifierIdentifier: .version1`, iOS 15+). The classifier emits a
per-window confidence for each known sound label. When a clap-family label
crosses the confidence threshold, that's one **clap event**.

**The "clap twice" gesture is preserved.** Two clap events, separated by a
release + minimum gap and within the window, still trigger — identical state
machine to the current detector. Only the *input* changes: from RMS-dBFS
crossings to classifier-confidence crossings. This keeps the app's identity
(clap twice) and stops a single TV-applause burst from firing.

## 2. Decisions (PM-delegated — agent's call)

1. **Sensitivity now maps to a confidence threshold** for clap mode
   (touch-alert motion sensitivity is unchanged):
   | Sensitivity | Confidence required |
   |---|---|
   | Low | 0.75 (very sure) |
   | Medium | 0.55 |
   | High | 0.40 (forgiving — catches distant/soft claps) |
   Starting defaults; calibrated on device in QA.
2. **The classifier drives detection; RMS energy thresholding is removed.**
   Clap sessions are short (press-listen → clap → found), so continuous
   classification's battery cost is acceptable here. A cheap RMS pre-gate
   (only wake the classifier on a transient) is a documented future option
   if device QA shows drain.
3. **The clap label is resolved at runtime**, not hard-coded: read
   `SNClassifySoundRequest(classifierIdentifier: .version1).knownClassifications`
   and match clap-family labels actually present (e.g. `clapping`,
   `applause`, `hands`). Authoritative, no guessed string.

## 3. Architecture

| Unit | Module | Responsibility |
|---|---|---|
| `ClapClassifier` | `ClapFinderKitAudio` (iOS; macOS stub) | Wraps `SNAudioStreamAnalyzer`; receives tap buffers; emits `(confidence, time)` for clap-family labels via a callback. `SNResultsObserving`. |
| `ClapDetector` | `ClapFinderKitAudio` | Owns the engine + tap; routes buffers to `ClapClassifier`; the existing two-events-in-window gesture machine consumes confidence crossings (threshold = sensitivity's confidence). RMS path removed. |
| `Sensitivity` | `ClapFinderKitData` | Adds `clapConfidenceThreshold` alongside the existing motion/dBFS values. |

The gesture state machine (`processSample(level:at:)` — release + min-gap +
window + cooldown) is unchanged and stays CLI-unit-testable. The
SoundAnalysis wrapper is iOS-only (`#if os(iOS)`), with a macOS stub so
`swift test` keeps working.

## 4. Risks (honest)

- **Battery/CPU:** continuous classification > RMS. Bounded here because clap
  listening sessions are short. Pre-gate is the fallback.
- **Latency:** analysis windows are ~0.5–1 s, so response is slightly slower
  than instantaneous energy detection.
- **Single sharp clap** may classify at lower confidence than sustained
  applause (the classifier leans toward applause/crowd). Mitigation: accept
  the whole clap-family label set; tune thresholds in device QA.
- iOS 15+ (target is 17 — fine).

## 5. Files + diff estimate

| File | ~LOC |
|---|---|
| `SOUND_RECOGNITION_DESIGN.md` | 70 |
| `ClapClassifier.swift` (new, iOS + stub) | 130 |
| `ClapDetector.swift` (route via classifier; drop RMS) | 70 |
| `Sensitivity.swift` (confidence threshold) | 15 |
| tests (gesture unchanged; confidence-threshold mapping) | 50 |
| `MIGRATION_VALIDATION.md` (distance / accuracy / battery QA rows) | 15 |

**≈ 350 LOC.** No UI change. Pure gesture logic stays testable on CLI;
real recognition accuracy is device QA.

## 6. Testing

- Unit: two-events-in-window gesture (reuses existing tests, fed confidence
  values); sensitivity → confidence-threshold mapping.
- Device QA: clap at 1/3/5 m and confirm fire; speech / door slam / cough do
  NOT fire; battery over a few minutes of listening; tune thresholds.
