# ADS_DESIGN.md — Banner + Interstitial (PR-12)

**Version:** v2 (PM rulings folded — approved for implementation)
**PR:** logical PR-12 `phase2/pr-12-banner-interstitial`
**Status:** Approved 2026-06-11. D1–D3 ruled as proposed: "use" =
clap listening start with attempt at stop-listening only; threshold
drawn 3–5 per cycle with not-loaded preserving the counter; banner
idle-only.

---

## 1. Hard constraints (PM, operating contract — non-negotiable)

1. Banner: **bottom of Home only.**
2. Interstitial: **1 per 3–5 uses**, counter **persisted**.
3. **Never during active detection or alarm** — enforced in code and
   pinned by a unit test, not just this doc line.
4. From the touch-alert contract: **no interstitial on arm/disarm
   actions**; **no ad of any kind while armed or alarming.**

## 2. Decisions (RULED — PM 2026-06-11)

**D1 — "Use" definition — RULING: approved.** One use = one **clap-mode
listening session start**. The interstitial attempt happens at
**stop-listening only**. Touch-alert sessions neither count as uses nor
trigger attempts — constraint 4 bans interstitials on arm/disarm, and
counting uses that can never pay out would silently starve the
placement.

**D2 — Frequency mechanics — RULING: approved.** At counter reset a
threshold is drawn uniformly from 3–5 and persisted alongside the
counter (`UserDefaults`). When `uses ≥ threshold` and all activity
flags are clear, the next stop-listening shows the loaded interstitial,
resets the counter, and draws a new threshold. A not-loaded suppression
at an eligible moment **preserves** the counter (the user owes no extra
uses because fill failed). RNG is injected for tests.

**D3 — Banner visibility — RULING: approved.** The banner renders
**only while fully idle** — not listening, touch alert disarmed. A
banner refresh is an ad trigger; constraint 4 bans triggers while
armed/alarming, and hiding during clap listening keeps the detection
screen clean for the same reason the contract bans interstitials there.
Container per DESIGN.md: 50 pt, full width, bottom-anchored,
`CFColor.adContainer`.

## 3. Mechanics

- **ATT:** both formats read ATT status at request time; not
  `.authorized` → non-personalized (`npa=1`) extras — same pattern as
  the App Open Ad.
- **Preload:** interstitial loads at app start and re-loads in the
  dismissal callback (GMA: a shown interstitial cannot be re-shown).
- **Failure:** no loaded ad at an eligible moment → suppressed with
  reason `not_loaded`; counter does NOT reset (the user owes no extra
  uses because fill failed).
- **Test IDs** (production IDs are PM-provided secrets, placeholders
  marked): banner `ca-app-pub-3940256099942544/2435281174`,
  interstitial `ca-app-pub-3940256099942544/4411468910`.

## 4. Architecture

| Unit | Module | Responsibility |
|---|---|---|
| `InterstitialPolicy` | `ClapFinderKitAds` | Pure decision: activity flags + counter vs threshold. Suppress-reason ordering: detection > alarm > frequency > not-loaded. |
| `InterstitialStore` protocol + `UserDefaults` impl | `ClapFinderKitAds` | Persisted `usesSinceLast` + `threshold`. |
| `AdPlacementAnalytics` | `ClapFinderKitAds` | Typed constructors per EVENTS.md. |
| `InterstitialController` | App target | GMA v12 load/present/preload, owns store, applies policy. |
| `BannerAdView` | App target | `UIViewRepresentable` over `BannerView`, anchored adaptive size. |
| HomeView wiring | App target | recordUse on listening start; attempt on listening stop; banner idle-only. |

## 5. Events (EVENTS.md, same docs commit)

`banner_loaded`, `banner_failed(error_reason)`,
`interstitial_shown(uses_since_last)`,
`interstitial_suppressed(reason: detection_active | alarm_active |
frequency_cap | not_loaded)`.

## 6. Testing

Unit (CLI): the **never-during-detection test** (constraint 3),
never-during-alarm, suppress-reason priority, frequency boundary
(threshold−1 suppressed / threshold shown), counter-reset + redraw,
not-loaded preserves counter, threshold always ∈ 3…5.

Device QA rows (consolidated pass): banner renders idle-only at
bottom; interstitial after 3–5 stop-listens; no interstitial on
arm/disarm; no banner while armed; interstitial dismiss returns to
Home with detection off.
