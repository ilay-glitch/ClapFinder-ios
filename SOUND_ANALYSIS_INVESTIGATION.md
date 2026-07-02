# SOUND_ANALYSIS_INVESTIGATION.md — should we return to Apple Sound Analysis?

**Type:** Written investigation — **doc & findings only, no production code.**
**Question:** PR-15 rejected SoundAnalysis for (a) confidence stuck at 0.4–0.7
and (b) ~1 s latency. Were those **framework ceilings** or **our-config
mistakes**? That decides whether a second attempt is worth it.
**Verdict (short):** Mostly **config + architecture mistakes**, with **one real
residual framework limit** (a 0.5 s window floor). Evidence below. Nothing in the
working crest-only path is touched by this doc.

---

## 1. What PR-15 actually did (recovered from git `1da6ffb` / `a2b6e58`)

The SoundAnalysis code was reverted in `cf255a9`; recovered `ClapClassifier.swift`
+ `Sensitivity.swift` + the v1 design doc show the exact configuration:

| Knob | PR-15 value | Note |
|---|---|---|
| Classifier | `SNClassifySoundRequest(classifierIdentifier: .version1)` | Apple's **built-in** general model — not a custom Create ML model |
| **`windowDuration`** | **never set** → framework default (~0.975 s) | ← the ~1 s latency |
| **`overlapFactor`** | **never set** → default 0.5 | results only ~every 0.49 s |
| Labels | `{clapping, applause, hands}` ∩ `knownClassifications` | applause-oriented |
| Confidence threshold | Low **0.75** / Med **0.55** / High **0.40** (`clapConfidenceThreshold`) | |
| Buffer | tap `bufferSize: 1024`, streamed to `SNAudioStreamAnalyzer.analyze` | fine |
| **Gesture** | the existing **two-events-within-`clapWindowSeconds` (0.5 s)** double-clap FSM, fed classifier-confidence crossings | ← see §4c |

Their own v1 doc even flagged two of the flaws without fixing them: *"analysis
windows are ~0.5–1 s, so response is slightly slower"* and *"single sharp clap
may classify at lower confidence than sustained [applause]."*

**Three latent flaws are visible in the config alone**, before any framework
question: window never tuned; overlap never tuned; and a 0.5 s double-clap
gesture running on top of a ~1 s classification window.

## 2. The framework's real knobs (Apple docs + guides, 2026)

- **`windowDuration` is settable** per request:
  `request.windowDuration = CMTimeMakeWithSeconds(seconds, preferredTimescale: 48_000)`.
- **`windowDurationConstraint`** reports the supported range. For the **built-in
  `.version1` classifier that range is 0.5 s … 15 s** — so the *minimum* window
  is **0.5 s**, and the default sits near ~0.975 s. PR-15 left it at the default.
- **`overlapFactor`** default **0.5**, range **[0.0, 1.0)**; higher overlap →
  results emitted more frequently (lower detection latency) at more CPU. Apple
  cautions >0.5 raises cost.
- **Built-in labels:** `.version1` (AudioSet-lineage, ~300 classes) *does* expose
  applause/clapping-family labels (PR-15's intersection was non-empty and it
  started) — but they are oriented to **sustained applause**, not a single clap.
- **Create ML custom sound classifier** (`MLSoundClassifier`): train on your own
  labelled audio (e.g. single/double claps); exposes the same `windowDuration` /
  `overlapFactor` model parameters (WWDC19 example: 0.975 s window, 0.75 overlap).
  It is built on the same audio feature extractor, so its window floor is similar
  (~0.5–0.975 s) — **a custom model buys accuracy/confidence for the target
  sound, not sub-0.5 s latency.**

## 3. The fork — config/architecture mistake vs framework ceiling

Per the two rejection reasons, plus the double-clap issue:

**(a) ~1 s latency → mostly CONFIG.** The default window (~0.975 s) was never
lowered. The built-in floor is **0.5 s** (§2), so a tuned request roughly halves
the window; raising `overlapFactor` (e.g. 0.8) makes detections land sooner
within that window. So the *measured* ~1 s was the un-tuned default, **not** the
floor. **Residual real limit:** 0.5 s is a hard floor for the built-in model
(and ~0.5–0.975 s for a custom one) — so SoundAnalysis latency-to-detection is
inherently **~0.5 s**, vs crest-only's **<~50 ms**. That gap is a genuine
framework property, not a mistake.

**(b) Confidence 0.4–0.7 → mostly CONFIG / MODEL CHOICE.** A single clap is a
~5–20 ms transient; in a ~1 s window it is surrounded by silence/room, so its
energy is *diluted* and the applause-trained "clapping" label scores modestly.
Two untested fixes both point at our choices, not a ceiling: a **shorter window**
(the clap fills more of it) and a **custom Create ML model trained on real
single/double claps** (a target-specific class scores far higher than a generic
applause label). Neither was tried.

**(c) Double-clap was structurally impossible → ARCHITECTURE mistake.** PR-15
kept the "two clap events within 0.5 s" gesture but fed it a **~1 s** window's
output. Two claps 0.15 s apart fall inside a *single* classification window →
they can never surface as two events. Even at the 0.5 s floor, one window ≈ the
whole double-clap gap. This alone would sink double-clap detection regardless of
confidence. The correct architecture is **single-clap classification**, or use
the classifier as a **per-event confirm while crest owns the double-clap
timing** (exactly the v3/v4 reject-only shape, with the classifier replacing the
hand-rolled spectral features).

**Conclusion:** PR-15 did **not** give SoundAnalysis a fair test — it ran the
default window, default overlap, an applause label, and an incompatible gesture.
The confidence and double-clap failures were ours to fix. The **only** true
framework limit is the **~0.5 s latency floor**.

## 4. Recommendation

**Worth a *properly configured* second look — but the bar to switch is real,
because crest-only already works and the parked v4 centroid plan is ~instant and
free.** The decision hinges on one unknown: does a correctly-configured
SoundAnalysis (or a custom Create ML model), used as a **reject-only per-event
confirm** (not a double-clap detector), beat crest + centroid by enough to
justify (i) a ~0.5 s latency floor and (ii) shipping a Core ML model? That is an
empirical question — resolve it with the smallest experiment (§5), not a rewrite.

Ranking to test, cheapest first: **built-in `.version1` @ `windowDuration` 0.5 s,
`overlapFactor` 0.8, single-clap** → if confidence separates claps from
speech/TV, done. If not, **custom Create ML clap model**, same wiring. If neither
clearly beats crest+centroid, **Sound Analysis stays rejected** and we keep
crest-only + the parked v4 centroid confirm.

## 5. Smallest on-device experiment (parallel, logged — does NOT replace crest)

Additive + DEBUG-only, same discipline as the diagnostics work. Crest-only stays
the live detector; the classifier runs **alongside** and only logs.

1. Add a `ClapClassifier` (recovered PR-15 code) configured **correctly**:
   `windowDuration = 0.5 s` (built-in floor), `overlapFactor = 0.8`, per-window
   **best clap-family confidence** (single clap — drop the double-clap-on-
   classifier idea).
2. Feed it the same tap buffers. On each classification result, **log** to the
   existing `clapdiag.csv`: `classifierConfidence` + a wall-clock timestamp,
   alongside the crest/centroid/zcr columns already there.
3. Run a labelled room session: real claps (near/2 m/room) + speech + TV.
4. Read three things from the data:
   - **Hit-rate:** does confidence reliably exceed a threshold on real claps?
   - **False-positive:** does speech/TV score high (would it over-trigger)?
   - **Latency:** wall-clock from the crest onset to the classifier's confidence
     crossing (measures the *real* window+overlap latency on device).
5. *(Optional arm 2)* a custom Create ML model trained on ~50–100 clap clips,
   same logging, to compare confidence separation vs the built-in.

Decision comes from that data: switch only if the classifier clearly out-
separates crest+centroid at an acceptable (~0.5 s) latency.

## 6. Fences

- **No detector rewrite.** Crest-only stays the shipping path throughout.
- Any classifier code from the experiment is **additive, DEBUG-only, parallel**
  (logs only; does not gate detection) until the data justifies a switch.
- Does not disturb the parked threads: **#37** (v4 centroid design), **#38**
  (diagnostic-columns build / ambient check), **#36** (Part C onboarding review).

## Sources

- [SNClassifySoundRequest — Apple Developer](https://developer.apple.com/documentation/soundanalysis/snclassifysoundrequest)
- [overlapFactor — Apple Developer (Create ML)](https://developer.apple.com/documentation/createml/mlsoundclassifier/modelparameters/3237373-overlapfactor)
- [MLSoundClassifier — Apple Developer](https://developer.apple.com/documentation/createml/mlsoundclassifier)
- [Identify individual sounds in a live audio buffer — Create with Swift](https://www.createwithswift.com/identify-individual-sounds-in-a-live-audio-buffer/) (windowDuration/overlapFactor API; built-in window range 0.5–15 s)
- [Discover built-in sound classification in SoundAnalysis — WWDC21](https://developer.apple.com/videos/play/wwdc2021/10036/)
- [Training Sound Classification Models in Create ML — WWDC19](https://developer.apple.com/videos/play/wwdc2019/425/)
