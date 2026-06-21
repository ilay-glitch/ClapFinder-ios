# SOUND_RECOGNITION_DESIGN.md — Clap detection

**Version:** v3 — hybrid: crest onset gate → lightweight spectral confirm
**Status:** Implemented & merged (#31), then **spectral veto DISABLED** (#33,
`spectralVetoEnabled = false`) after the device tuning session exposed a feature
bug — see **§13**. The veto stays OFF; round-two redesign deferred.
**PR:** logical PR-18 → merged as #31.
**Supersedes:** v2 (crest factor alone).

> Numbering note: the brief called this "round two / v2"; the file was already
> at **v2** for the energy+crest revert, so this is **v3** to keep history
> straight.

---

## 1. The problem, now proven on device

v2 used **crest factor** (peak ÷ RMS) as the *sole* clap-vs-noise
discriminator. Device use is unambiguous: it fires on essentially **every
above-floor sound** — knocks, single taps, speech bursts, TV, music. That is
exactly the predicted failure and needs no CSV to confirm: **crest measures
impulsiveness, not timbre.** A knuckle-knock and a clap are both sharp
transients → both high crest → indistinguishable in crest space.

Crest is **necessary** (cheap, distance-stable onset detection) but **not
sufficient**. Round two adds the one axis crest lacks: **spectral shape.**

## 2. Architecture — two stages, reject-only

```
audio buffer
   │
   ▼
┌──────────────────────────┐   stage 1 — UNCHANGED from v2
│ crest onset gate          │   dBFS > floor AND crest > threshold
│ (the PRIMARY detector)    │   • cheap, runs every buffer
│                           │   • this gate alone sets distant-clap REACH
└──────────────────────────┘
   │ peak candidate (rarely)
   ▼
┌──────────────────────────┐   stage 2 — NEW
│ spectral confirm (VETO)   │   one FFT on the onset buffer
│ reject-only               │   • can only turn ACCEPT → REJECT
│                           │   • never promotes a non-peak
└──────────────────────────┘
   │ confirmed peak
   ▼
┌──────────────────────────┐   UNCHANGED from v2
│ double-clap FSM           │   two peaks · release · gap · window · cooldown
└──────────────────────────┘
```

The key property is the **asymmetry**: stage 2 is a veto applied only to
buffers stage 1 already accepted. It can reject a false positive; it can never
fail to catch a clap that stage 1 caught. Errors fall on the side of
preserving claps (see §6).

## 3. The spectral feature(s) — what actually separates the three (point 1)

| Source | Spectral signature | Measurable |
|---|---|---|
| **Clap** | broadband, noise-like, energy well into the highs (2–8 kHz+), very fast decay | **high HF-energy ratio**, **high spectral flatness** |
| **Knock** (knuckle on wood/desk) | low-frequency dominant — the surface resonance sits ~100–800 Hz, little HF | **low HF-energy ratio** |
| **Speech** | harmonic (glottal pitch + formants), energy mostly < 4 kHz, *sustained* across buffers | **low spectral flatness** (peaky/tonal), long sustain |

Two cheap, complementary features from one FFT of the onset buffer:

1. **HF band-energy ratio (HFR)** — `Σ power(f ≥ 2 kHz) ÷ Σ power(all)`.
   The single most discriminating, cheapest feature. A clap is *bright*
   (broadband HF); a knock is *dull* (LF-dominant). **Primary.**
2. **Spectral flatness (SFM)** — `geometric_mean(power) ÷ arithmetic_mean(power)`.
   ≈1 → noise-like/broadband (clap); ≈0 → tonal/peaky (speech harmonics,
   resonant knock). **Catches speech that HFR alone might pass.**

Optional tiebreaker, already measured by the PR-17 diagnostics path: the
**in-buffer decay slope / sustain** — claps decay in ~1 buffer, speech sustains
across many.

**Decision rule (reject-only):** do **not** veto iff `HFR ≥ τ_hfr` **AND**
`SFM ≥ τ_sfm`; otherwise reject as a non-clap. Per source:
- **clap** → HFR high, SFM high → **passes**
- **knock** → HFR low → **vetoed**
- **speech** → SFM low (+ sustained) → **vetoed**
- **single tap** → may pass spectral, but a lone impulse still fails the
  double-clap FSM anyway.

**Bands (concrete):** at a 48 kHz input, a 1024-point FFT gives ~46.9 Hz bins
(512 usable). HF cutoff 2 kHz ≈ bin 43; HFR sums bins 43…511 over 1…511.
Sample rate is read from the tap format, not assumed.

**Proposed starting thresholds (TBD by device tuning, deliberately lenient):**
`τ_hfr ≈ 0.20`, `τ_sfm ≈ 0.15`. These reject only *clearly* LF-dominant or
*clearly* tonal sounds; anything ambiguous passes (favor clap recall — §6).

## 4. Hand-rolled vDSP, not SoundAnalysis/YAMNet (point 2 — CONFIRMED)

Confirmed: a lightweight hand-rolled spectral gate, **not** the heavy model. It
is the only option that avoids **both** failures that got SoundAnalysis
reverted:

| Reverted failure | Hand-rolled vDSP gate |
|---|---|
| **0.4–0.7 confidence, frequent misses** | No soft model probability. We compute a *deterministic scalar* (HFR/SFM) on the exact onset buffer and threshold it — a targeted binary "LF-dominant / tonal?" reject, not a 521-class model's clap score. |
| **~1 s analysis window (latency)** | One 1024-pt real FFT on a *single* buffer when the onset gate fires — not a rolling 1 s window. Sub-millisecond (§5). |

Extra wins: no model load, no per-buffer ANE/CPU cost, fully deterministic and
**unit-testable**, and it *composes* with the existing crest FSM instead of
replacing it (no fourth rewrite — we keep v2 and add a veto).

**Push-back / honest scope:** a hand-rolled gate is *not* a general classifier
— it cannot tell a clap from a balloon pop or a snare hit. It doesn't need to.
Our real-world false positives (knock, tap, speech, TV) have clear, opposite
spectral signatures (LF-dominant or tonal/sustained), which two band/flatness
thresholds separate cleanly. If a future need arises for fine-grained
classification, *that* is when YAMNet earns its cost — not now.

## 5. Latency budget (point 3 — under "feels instant")

The spectral confirm runs **only when the crest onset gate flags a peak** —
i.e. on sharp transients, a handful of times per real event, **not** every
buffer. To keep it rare without threading state across actors, the FFT is gated
in the tap by a fixed, most-lenient crest pre-check (≈ the High-sensitivity
crest), so it fires only on impulsive buffers; the HFR/SFM ride to the main
actor alongside dBFS/crest.

Per evaluation: copy 1024 floats → Hann window (`vDSP_vmul`) → 1024-pt real FFT
(`vDSP_fft_zrip`) → magnitudes (`vDSP_zvmags`) → two band sums (`vDSP_sve`) +
a log-mean for SFM. On A-series silicon a 1024 real FFT is ~10–30 µs; the whole
step ~**50–100 µs**. A double-clap evaluates it twice → **~0.2 ms added total**.

The "feels instant" threshold for UI response is ~100 ms. We are **~3 orders of
magnitude under it.** Confirmed: no perceptible latency.

## 6. Distant-clap reach survives (point 4 — CONFIRMED, reject-only)

Confirmed framing. Reach is owned entirely by **stage 1** (crest gate +
calibration), which is **unchanged**. Stage 2 is a **veto** that only ever
turns an accept into a reject — it never has to *catch* a clap the crest gate
missed, and never promotes a non-peak. Therefore it **cannot reduce reach.**

The one physical caveat: HF attenuates with distance (air absorption + mic
roll-off), so a far clap is less bright. We protect against this two ways:
1. **Lenient `τ_hfr`** — set to reject only *clearly* dull (LF-dominant)
   sounds; a distant-but-real clap is still broadband enough to clear it.
2. **Favor recall on ambiguity** — when a candidate is borderline, it
   **passes**. Worst case is a *missed veto* (a false positive slips through),
   **never a missed clap.**

If device tuning ever shows a distant clap getting vetoed, the fix is to loosen
`τ_hfr` — never to touch stage 1. (On Bluetooth / non-built-in mic routes the
veto is disabled entirely — see §11 Known limitations.)

## 7. Thresholds & tuning (data-driven, not guessed)

Reuse the **PR-17 diagnostics stream**: add `hfr` and `sfm` columns to the CSV.
A labeled session (claps near/far vs knock/tap/speech/TV) gives the actual
distributions; set `τ_hfr`, `τ_sfm` at the gap, starting **permissive** and
tightening only as the data supports. The thresholds ship as named constants,
overridable the same way crest already is. No threshold is hard-coded from this
doc — §3's values are starting points.

## 8. Testing

- **Pure-logic spectral features** (`hfr(samples:sampleRate:)`,
  `spectralFlatness(samples:)`) on synthetic signals, CLI-testable, no mic:
  broadband noise burst (clap-like) → high HFR & SFM; low-frequency sine
  (knock-like) → low HFR; harmonic stack (speech-like) → low SFM.
- **Reject-only invariant**: a unit test asserting the spectral stage can only
  downgrade an accept, never create one.
- The existing crest **FSM behaviour suite is unchanged and must stay green** —
  proof stage 1 / reach did not move.

## 9. Rulings (PM, 2026-06-17)

- **Numbering:** stays **v3**. v2 (energy+crest) is real history — not renumbered.
- **Bluetooth / non-built-in routes:** **disable the spectral veto, fall back
  to crest-only.** HF roll-off vetoing real claps for AirPods users is worse
  than an occasional false positive. Documented in §11, not buried.
- **Calibration:** stays **crest-only for v1.** No spectral profiling in
  calibration until the basic spectral gate is proven on-device — that's a
  later optimization of a solution not yet validated.
- **Thresholds:** ship **permissive (favor-recall)**; tune from real numbers,
  not guessed values (see §10 condition 1).
- **Window function:** Hann, fixed (not a tunable).
- **`mixWithOthers` + music:** no echo handling in v1; detection during active
  alert playback is rare. Revisit only if QA shows self-triggering.

## 10. Implementation acceptance conditions (PM)

1. **Thresholds start permissive**, and the `hfr` / `sfm` **diagnostic columns
   ship WITH the implementation** — so the labeled device session tunes
   `τ_hfr` / `τ_sfm` against real numbers, never guessed values baked in.
2. **The crest stage stays byte-for-byte untouched** (same as the diagnostics
   PR). The spectral gate is purely additive. **Existing detector tests must
   stay green before the spectral code lands** — same pure-refactor discipline
   as the `AlarmResponder` extraction.

## 11. Known limitations

- **Bluetooth / non-built-in microphones: spectral veto disabled, crest-only.**
  Many BT mics (AirPods, headsets) roll off high frequencies hard, which would
  make real claps look "dull" (low HFR) and get vetoed. On any non-built-in
  input route the detector falls back to the v2 crest-only behaviour (we
  already observe `routeChange`). Trade-off: BT users may see the occasional
  false positive the spectral gate would otherwise catch — accepted, because
  missing real claps for them is worse.

## 12. Out of scope

No change to the crest gate, distant-clap reach, the double-clap FSM, or
calibration semantics. The spectral confirm is **purely additive** — a veto
layered on the v2 detector, tunable from data, removable by route.

---

## 13. Device tuning session findings (2026-06-21)

After #31 shipped the veto with the **never-tuned guess thresholds**
(`hfr 0.20` / `sfm 0.15`), a build from main detected **no claps**. We disabled
the veto (#33, `spectralVetoEnabled = false`, crest-only) and ran a labeled
device session — real claps only, 301 candidate rows pulled off-device via the
file-logger + `devicectl copy`. Two findings.

### 13.1 The spectral veto rejected 100 % of real claps — `sfm` is a broken feature

- **0 / 301** real-clap rows passed `hfr ≥ 0.20 AND sfm ≥ 0.15` → with the veto
  on, every clap is vetoed. That *is* the no-detection regression.
- **`sfm` is pinned**: 0.000–0.030 across all 301 frames (81 exactly `0.000`),
  while `hfr` varied ~800× (0.001–0.831). Even the strongest claps (crest > 8)
  read `sfm` ≈ 0 → it tracks nothing.

**Mechanism — geometric-mean collapse.** `sfm = geomean / mean` over 511 bins,
geomean = `exp(mean(log(power)))` with a `max(power, 1e-20)` floor. The geomean
is **dominated by the smallest bins** (`ln(1e-20) ≈ −46`). A real clap through a
phone mic is **band-limited** (HF rolloff, room colour), so a large block of
high bins sit near zero → hit the floor → drag `logMean` hugely negative →
geomean → ~0 → **`sfm` pins near zero regardless of the signal.**

**Why the unit test masked it.** `ClapSpectralTests.broadbandIsClapLike` feeds
*uniform white noise* — the one input whose every bin is ~equal, so the geomean
can't collapse and SFM reads high. White noise is unrepresentative of real mic
buffers; the test is now annotated as such and must **not** be read as proof the
feature works on-device.

**Verdict:** a computation/feature-design fragility (artifact), compounded by an
optimistic v3 assumption (real single-frame claps are *not* spectrally flat). As
built, `sfm` cannot discriminate anything. **The veto stays OFF.**

### 13.2 Calibration drove the crest threshold too low (fixed here)

Live calibrated threshold was **2.07** (`2.07 ÷ 0.7 margin = 2.96` weakest clap
— **not** floor-clamped). With operational median crest 3.50, almost every
buffer read as a peak → **218/301 `noRelease`** → the double-clap FSM starved
for releases → a 139-row dead zone of missed claps ("broke partway through").
**Fix:** `margin 0.7 → 0.85` (threshold sits just under the weakest clap) and
raise the clamp **floor**. Reach is worthless if the FSM can't pair the claps.

**Floor iteration (device-measured, not guessed):**
- `2.0 → 2.5`: still starved — noRelease 70 %, only **11/208** buffers fell
  below threshold (releases).
- `2.5 → 3.0`: the session crest distribution put inter-clap gaps at **p25 ≈
  2.88** and clap peaks at the **3.51 median**; 3.0 sits in the valley between
  them, turning **~62/208** buffers into releases. **Caveat:** the weakest
  calibration clap (~2.94) nearly overlaps the gap ceiling (~2.88) — crest-only
  separation is *narrow* for this mic/room. If 3.0 still starves or starts
  dropping real claps, that is evidence crest-only is at its limit → input to
  the crest-vs-spectral (round-two) decision.

### 13.3 Open question for round two — the next measurement

`hfr` *varied* meaningfully with the signal (~800×), so it may carry real
discriminative power — **but Session 1 was claps-only**, so we cannot yet say
`hfr` separates claps from knocks / speech. That is the **next measurement**: a
claps-vs-noise labeled session (the file-logger + `devicectl copy` pipeline is
in place). Round-two direction (HFR-only + a different speech discriminator, a
robust flatness estimator, or a longer analysis window) is **deferred** until
that data exists — not a decision now.
