# SOUND_RECOGNITION_DESIGN.md — Clap detection

**Version:** v4 — hybrid retained; SFM replaced by **spectral centroid (+ ZCR)**.
DESIGN PROPOSAL (doc only — hold for redline; no code until the §14.7 v1 decision).
**Status:** v3 shipped with the veto OFF (#33) after **§13** exposed the SFM bug.
Round-two research **confirms the v3 architecture** (crest gate → reject-only
spectral confirm) and **replaces the broken feature** (SFM). v4 (**§14**)
proposes the corrected discriminator and the measure-first plan to set its
thresholds. No code until redline + the ship-now-vs-post-launch decision (§14.7).
**PR:** logical PR-18 → merged as #31 (veto currently OFF). v4 design: this doc.
**Supersedes:** v3 §3's *feature* choice (SFM); the *architecture* is unchanged.

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

---

## 14. v4 — round-two design: the corrected spectral discriminator

Round-two literature research (2026-06-22) on clap/percussion detection.

### 14.1 What the research confirmed — and corrected

- **Confirmed (architecture):** energy/crest alone is *insufficient*; a clap
  must be characterised by **spectral** features; and a **crest onset gate →
  reject-only spectral confirm** is the right structure. v3's architecture
  (§2) stands.
- **Corrected (feature):** the failure was the *specific* discriminator — **SFM
  via geometric mean** — not the idea of a spectral confirm. §13.1 showed the
  geomean collapses to ~0 on band-limited real claps. We replace the feature,
  keep the structure.

### 14.2 Why SFM failed (recap of §13.1)

`sfm = geomean / mean`; the geomean = `exp(mean(log P))` is dominated by the
*smallest* bins (`ln(1e-20) ≈ −46`). Real claps through a phone mic are
band-limited → many near-zero HF bins → geomean → 0 → `sfm` pinned (~0.001
across 301 frames while `hfr` varied ~800×). **Lesson: any replacement must not
be dominated by near-zero bins.** That single criterion eliminates geomean-style
features and points at **means and percentiles**.

### 14.3 Candidate features evaluated

| Feature | What it is | Clap vs speech vs knock | On-device cost | Near-zero-bin safe? | Reject-only fit |
|---|---|---|---|---|---|
| **Spectral centroid** | energy-weighted mean frequency `Σ(f·P)/Σ(P)` | clap **high** (bright/broadband); speech **low** (energy <~3 kHz); knock **low** (LF) → separates clap from **both** in one scalar | dot-product + sum over the FFT we already run (`vDSP`) | **Yes** — a weighted *arithmetic* mean; near-zero bins add ~0 to num & den, can't collapse it | veto when centroid **low** |
| **ZCR** | zero-crossing rate of the time-domain samples | broadband/percussive **high**; LF knock **low**; voiced speech low — *caveat:* fricatives (s/sh) are high | **~free, no FFT** — one pass over samples (already scanned for peak) | n/a (time-domain) | veto when ZCR **low** |
| **Spectral rolloff (85%)** | freq below which 85% of energy sits | same direction as centroid; clap **high** | cumulative sum over the FFT, find crossing bin | **Yes** — a percentile, robust to a few stray bins | veto when rolloff **low** |
| **HFR (existing)** | energy ≥2 kHz ÷ total | clap higher; a coarse 2-band centroid | already computed | **Yes** (ratio of sums) | veto when HFR **low** |

### 14.4 Recommendation — which feature replaces SFM

**Primary: spectral centroid.** It is the direct, structurally-correct SFM
replacement:
1. It is a **weighted mean**, so it is *immune* to the exact failure that killed
   SFM (§14.2) — the decisive criterion.
2. It separates a clap from **both** non-clap classes at once — speech (energy
   concentrated <~3 kHz → low centroid) and knock (LF → low centroid) — where
   SFM only ever targeted "tonal" and HFR only ever targeted "dull."
3. It **reuses the FFT** already computed for HFR; marginal cost is a dot product.

**Secondary, free: ZCR.** Time-domain, no FFT, near-zero cost; an *independent*
corroborator computed in the tap. Likely role: a cheap second vote (veto only if
centroid **and** ZCR both say non-clap) to harden against centroid jitter — its
fricative caveat means it is a *complement*, never the sole discriminator.

**Drop SFM** (broken estimator). **Keep HFR + add rolloff as logged-only
diagnostics** for the tuning session — both are near-zero-bin-safe and let the
data decide whether centroid alone separates, or whether a second feature earns
its place. Final veto rule (centroid-only vs centroid+ZCR vs centroid+rolloff)
is **set from the session distributions, not chosen here.**

> ⚠️ **Centroid-inversion warning (device data, 2026-06-22).** In the first
> on-device window with the centroid columns live, the user's real claps read
> **LOW centroid (256–527 Hz, hfr 0.01–0.07)** while the played alert's
> transients read **HIGH centroid (1.7–4.7 kHz)** — the *inverse* of the
> literature's "claps are bright." Same band-limiting seen in §13.1. If the
> full labeled claps-vs-noise session confirms this, the veto direction must
> be **inverted** (veto HIGH-centroid transients) or the centroid plan
> **killed**. Do not build v4 as-designed until that session decides. Sample
> was one short window — measure, then build.

### 14.5 Architecture — unchanged from v3 (reject-only)

```
crest onset gate (UNCHANGED — owns reach)  →  spectral confirm (veto only)
```
The spectral stage can only **downgrade** a crest accept, never promote a
non-peak (the structural property proven by the reject-only invariant test).
Distant-clap reach stays entirely with the crest gate; the spectral confirm only
removes false positives. Bluetooth/non-built-in routes keep the crest-only
fallback (§11). The `spectralVetoEnabled` master switch (default OFF, #33) is the
bolt-on point — flip it on once thresholds are tuned.

### 14.6 Thresholds come from a labeled session — never baked guesses

This is the lesson of §13 made procedural. Before any veto re-enables:
1. Add **diagnostic columns** to the `clapdiag.csv` stream: `centroidHz`,
   `zcr`, `rolloffHz` (keep `hfr`). Veto stays OFF; features are logged for
   every above-floor candidate (the file-logger + `devicectl copy` pipeline is
   already in place).
2. Run a **claps-vs-noise** labeled session — claps near/2 m/another room **plus**
   knock, single-tap, speech, TV/applause.
3. Read the real distributions; set `τ_centroid` (± `τ_zcr`) at the **valley
   between the clap cluster and the non-clap cluster**, permissive side. If the
   clusters overlap (no clean valley), that is itself the finding — crest-only
   is the ceiling and the veto buys little.

### 14.7 Cost/benefit — do we do this for v1? (engineering read)

**Recommendation: ship v1 crest-only; add the spectral confirm post-launch,
data-driven.** Reasoning:

- **It already works.** Crest-only (calibration floor 3.0) detects claps with
  9/9 pairing; the dead-zone is gone. Functional today.
- **The spectral layer is a clean bolt-on with zero reach risk.** It is
  reject-only and gated by `spectralVetoEnabled` (already merged, OFF). Adding it
  later flips one flag — it cannot regress crest reach by construction. So
  deferring it costs **nothing architecturally**; there is no "rewrite later"
  penalty.
- **We don't yet know the real-world false-positive rate.** The veto only
  reduces false positives (knock/speech/TV triggering). Whether that is a real
  user problem or a rare edge is unmeasured. Post-launch usage / review signal
  tells us if the tuning investment is warranted — better than guessing now.
- **The spectral layer does not fix the one known weakness.** The thin recall
  margin (faintest clap 3.16 vs threshold 3.0) is a *recall* issue; a reject-only
  veto can only *lower* recall. So it is irrelevant to the margin concern (which
  is calibration, §13.2) — another reason it is not v1-critical.

> **MEASURED 2026-07-02 — criterion TRIPPED, decision FLIPPED.** The ambient
> check ran (TV room, five sessions): **6.7–15.6 ACCEPTs/min** — an alert every
> ~4–9 s in a TV household. That is a v1 quality blocker; **specificity work is
> v1-REQUIRED, not post-launch.** Feature direction from the same data (crude
> loud-vs-quiet labels): claps are NOT centroid-inverted vs ambient (820 Hz vs
> 311 Hz medians) but the distributions overlap heavily; **hfr separated best
> (0.117 vs 0.021, 5.6×)** > centroid (2.6×) > zcr (2×). The clean TV-off
> labeled session decides which feature the veto is built on.

**The one criterion that flips this to "do it for v1":** a quick **ambient
false-positive check** on device — if normal talking / TV / household noise
triggers detection *often* (not just deliberate bangs), that is a v1 quality
blocker for an All-Ages app, and we implement centroid before launch. If only
deliberate non-claps trigger and ambient rooms are quiet, ship crest-only and add
the veto post-launch. **Cheap to decide; one listening session in a normal room.**

### 14.8 Open questions for redline

1. Centroid-only vs centroid+ZCR for the veto — or leave it "decide from the
   session"? (I lean: ship the diagnostics for all of centroid/zcr/rolloff, decide
   the rule from data.)
2. v1 vs post-launch (§14.7) — your call; I recommend post-launch unless the
   ambient FP check fails.
3. If/when we build it: own PR, doc-led, reject-only invariant test retained, and
   the same measure-first gate (session before thresholds).


---

## 15. Response-side guards (2026-07-02 — from the loop reconstruction)

Device reconstruction of the "barking forever" bug found **three stacked
mechanisms**, fixed in order:

1. **Self-feedback** (the alert re-triggering detection): fixed by suppression
   anchored to `SoundPlayer.lastPlaybackEndedAt` — *proven working on-device*
   (suppressed ACCEPTs visible inside the grace).
2. **The firstClap-seeding leak**: output-filtering only suppressed *ACCEPTs*;
   a bark-tail transient could still seed `firstClap` inside the grace and
   pair with an ambient transient just past it. Fixed by a **hard feed gate**:
   while the response plays (+1.5 s tail) — and during the first **1.0 s after
   engine start** (the fire-on-Start transient) — buffers are dropped *before*
   the FSM (`gated` rows in diagnostics). Gated buffers cannot seed anything.
3. **Ambient re-trigger chains** (TV generating fresh ACCEPTs at 6.7–15.6/min):
   no suppression window can end these — they are independent false positives.
   Mitigated by a **response rate limit** (`ResponseCoordinator
   .minResponseInterval = 10 s`, named constant, tunable); *solved* only by the
   v1-required specificity work (§14.7 measured note).
