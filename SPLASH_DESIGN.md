# SPLASH_DESIGN.md — Splash / Loading Screen + App Open Ad

**Version:** v2 (PM redlines folded — approved for implementation)
**PR:** PR-10 `phase2/pr-10-splash-app-open-ad`
**Status:** Approved 2026-06-10. Redline log: §6.5 late-ad-discard
approved; §5 weighting approved; §8 `ad_skip_reason` added to
`splash_completed`; mockup reference canonical.

---

## 1. Purpose

An animated splash screen shown on cold launch that doubles as the
App Open Ad loading window. Two jobs, one rule:

1. Give the app a warm, branded first moment while the animal catalog
   and (when eligible) an App Open Ad load.
2. **Never hold the user hostage.** Hard ceiling of 5 seconds; the
   splash always transitions to Home, ad or no ad.

PM decision (locked): App Open Ads ARE in scope. The app is free +
ads only; app open is the highest-eCPM placement for utility apps.
The constraints in §6 make the placement non-abusive.

---

## 2. Visual spec

Primary target: `LOADING_SCREEN_MOCKUP.html` (repo root, committed
2026-06-10). The PM-provided screenshot is a secondary reference; on
conflict the mockup wins.

Layout, top to bottom (geometry from the mockup's 393 pt frame):

| Element | Spec |
|---|---|
| Background | Full-screen vertical gradient `CFGradient.splashNight`, 5 stops at 0 / 30 / 55 / 78 / 100 % (§3) |
| Stars | 7 white circles, 3–5 pt, fixed positions per mockup; twinkle = opacity 0.25→1.0 + scale 0.8→1.15, 2.4 s loop, staggered delays |
| Moon | 84 pt circle, radial gradient `splashMoonCore → splashMoonEdge` (highlight at 35 %/35 %), glow shadow `splashMoonEdge` 0.35 opacity; ≈86 pt from top, 56 pt from trailing |
| Hills | Two half-ellipses anchored to the bottom: back `splashHillBack` at 0.8 opacity, front `splashHillFront` |
| Paw prints | 3 × 🐾 at 0.18 opacity, rotated, scattered over the hills |
| Title | "ClapFinder" — SF Rounded heavy ~44 pt, gradient text fill `CFGradient.titleGold`, drop shadow; ≈230 pt from top |
| Tagline | "Clap your hands — your phone answers! 🐶" — SF Rounded semibold ~19 pt, white 0.92 opacity |
| Characters | Row above the hills: 👏 ≈92 pt, clap loop (rotate −6°→+6° + scale →1.12, 1.1 s) with 2 ✨ sparks popping at mid-clap; 🐶 ≈96 pt bouncing −16 pt (1.1 s); 📱 ≈44 pt rotated 12° at the dog's feet, with 3 gold arc sound-waves scaling 0.6→2.1 while fading, staggered 0.25 s |
| Progress bar | Capsule track 14 pt high (white 0.28 opacity), fill `CFGradient.splashBar` with soft glow; ≈64 pt from bottom |
| Progress label | "Loading %d%%…" above the bar, synced to fill |
| Ad disclaimer | "This action can contain ads" below bar (white 0.75) — shown **only while an ad request is in flight** (§6); never on first launch |

The mockup's bar animates on a fixed 6 s ease-out demo curve — that
is a mockup device only. The implementation drives the bar with real
readiness per §5 (and §4's 5 s ceiling overrides the mockup's 6 s).

All user-visible strings live in `Localizable.strings`
(`splash.tagline`, `splash.loading`, `splash.adDisclaimer`).

Emoji characters are v1 — consistent with the Home screen's emoji
grid. Upgrade path: custom illustration set swaps in as assets later,
no layout change.

### Accessibility

- **Reduce Motion:** scene renders static (no twinkle, no clap loop,
  no rings); progress bar animation only.
- Progress announced via accessibility value on the bar; splash is an
  `accessibilityElement(children: .contain)` with the title as label.
- Disclaimer text meets 4.5:1 contrast on the darkest gradient stop.

---

## 3. New design tokens (DESIGN.md amendment, same docs commit)

`ClapFinderKitDesign` additions — **brand/button gradients untouched**:

All hex values are taken verbatim from `LOADING_SCREEN_MOCKUP.html`:

| Token | Value | Use |
|---|---|---|
| `CFGradient.splashNight` | `#2B1055 → #4A1A6B → #7B2D8B → #C44B8C → #F0735A`, stops 0/30/55/78/100 % (top→bottom) | Splash background only |
| `CFGradient.titleGold` | `#FFD96B → #FF9D6B → #FF6BB5` (leading→trailing) | Splash title text only |
| `CFGradient.splashBar` | `#FFD96B → #FF8A5C → #FF5CA8` (leading→trailing) | Splash progress fill only |
| `CFColor.splashMoonCore` | `#FFF8D6` | Moon radial center |
| `CFColor.splashMoonEdge` | `#FFD96B` | Moon radial edge, glow, sound-wave arcs |
| `CFColor.splashHillBack` | `#5C2475` | Back hill |
| `CFColor.splashHillFront` | `#471D62` | Front hill |
| `CFColor.splashBarGlow` | `#FF8A5C` | Progress-bar glow (0.8 opacity) |

Rationale: the night scene needs darker anchors than `CFGradient.brand`
(`#8B5CF6 → #EC4899 → #F97316`), which stays the token for buttons,
toggles, and selected states everywhere else.

---

## 4. Splash timing

| Rule | Value |
|---|---|
| Minimum duration | 1.5 s (no flash-blink on fast loads) |
| Maximum duration | 5.0 s (= ad load timeout) |
| Background mid-splash | State freezes; on return the same cycle resumes. The ad request is **never** restarted. |

---

## 5. Progress semantics

The bar tracks real readiness, not a fake timer:

```
adResolved  = ad loaded ∨ ad failed ∨ ineligible ∨ timed out
readiness   = 0.3 × catalogLoaded + 0.7 × adResolved
progress(t) = max(progress(t-1),                    // monotonic
                  min(t / 1.5s, readiness))         // never ahead of readiness,
                                                    // never done before min duration
```

- Catalog load = `CatalogStore` ready (effectively instant; weight
  exists so the bar moves immediately).
- Because `adResolved` includes failure/timeout/ineligible, progress
  always reaches 100% at ≤ 5 s.
- The percentage label is the same value, rendered as an integer.

---

## 6. App Open Ad policy (hard rules)

All five must hold for an ad request to fire ("eligible"):

1. **Cold launch only.** Warm resume (foregrounding) never shows an
   app open ad. Warm-resume ads are explicitly out of scope for this
   PR; revisit only with frequency data in a later phase.
2. **Never on first launch.** First-ever launch (persisted
   `UserDefaults` flag) goes splash → Home with no ad request and
   **no disclaimer**. First impressions are ad-free.
3. **Max 1 per session.** In-memory session flag.
4. **≥ 4 h between app open ads.** Last-shown timestamp persisted in
   `UserDefaults`; compared via injected clock (§9).
5. **Timeout fallback.** If the ad has not loaded 5 s after request,
   transition to Home without it. A late-arriving ad after timeout is
   discarded (not shown, not cached for warm resume).

**ATT interplay:** eligibility check reads
`ATTrackingManager.trackingAuthorizationStatus` at request time.
Status ≠ `.authorized` → request carries non-personalized-ads extras.
The ATT prompt fires from the splash's `onFinished` handler (0.5 s
after Home appears) — never over the splash itself. It still always
precedes the first possible ad request because rule 2 blocks
first-launch ads. *(Amended 2026-06-11: originally 1.5 s after first
`.active`, which landed the system alert on top of the splash.)*

**Core-feature guarantee:** the splash/ad cycle runs only at cold
launch, before detection can be armed. No ad logic exists anywhere in
the detection / response pipeline.

---

## 7. State machine

States: `loading(adState)` → `presentingAd` → `done`
Ad sub-states: `idle | ineligible | requesting | loaded | failed | timedOut | shown`

```
cold launch
  └─► SPLASH [splash_shown]
        ├─ catalog load ──────────────────────────┐
        ├─ min-timer 1.5 s ───────────────────────┤
        └─ eligibility check (§6 rules 1–4)       │
             ├─ ineligible ───────────────────────┤
             └─ eligible → request [app_open_ad_requested]
                  ├─ loaded ≤ 5 s ── hold until catalog ∧ min-timer ──► PRESENT AD
                  │                                │      [app_open_ad_shown]
                  ├─ failed [app_open_ad_failed(reason)] ──┤      │ dismissed
                  └─ 5 s timeout [app_open_ad_timeout] ────┤      ▼
                                                   └────► HOME
                                            [splash_completed(duration_ms, ad_shown)]

backgrounded mid-splash → freeze; resume continues same state (no re-request)
```

Transitions are pure functions in `SplashStateMachine` (no Date(),
no timers inside — time arrives as events), so every path unit-tests
without sleeping.

---

## 8. Analytics (EVENTS.md created in same docs commit)

| Event | Params |
|---|---|
| `splash_shown` | `cold_launch: Bool`, `first_launch: Bool` |
| `app_open_ad_requested` | `att_authorized: Bool` |
| `app_open_ad_shown` | — |
| `app_open_ad_failed` | `error_reason: String` |
| `app_open_ad_timeout` | `elapsed_ms: Int` |
| `splash_completed` | `duration_ms: Int`, `ad_shown: Bool`, `ad_skip_reason: String` |

`ad_skip_reason` enum — distinguishes "fill problem" from "cap
working as designed" in the funnel:

| Value | Meaning |
|---|---|
| `none` | Ad was shown |
| `first_launch` | Rule 2 — first-ever launch, no request made |
| `frequency_cap` | Rule 4 — < 4 h since last app open ad |
| `session_cap` | Rule 3 — already shown this session |
| `load_failed` | Request made, SDK returned an error |
| `timeout` | Request made, not loaded within 5 s |

Transport: `AnalyticsClient` protocol in `ClapFinderKitAds` with an
OSLog-backed default. **No Firebase in this PR** — the Firebase
adapter conforms to the same protocol in the analytics PR.

---

## 9. Architecture

| Unit | Module | Responsibility |
|---|---|---|
| `AppOpenAdPolicy` | `ClapFinderKitAds` | Pure eligibility + frequency cap. **Clock injected** (`now: () -> Date` or `Clock`-protocol seam) — no `Date()` calls inside logic, so 4 h-interval tests run without sleeping. Storage injected (`UserDefaults`-backed protocol). |
| `SplashStateMachine` | `ClapFinderKitAds` | Pure state/transition logic per §7. |
| `AnalyticsClient` | `ClapFinderKitAds` | Protocol + `OSLogAnalyticsClient` default. |
| `AppOpenAdLoader` | App target (`ClapFinder/Ads/`) | Thin GoogleMobileAds wrapper: load, present, delegate → state-machine events. |
| `SplashView` + `SplashViewModel` | App target (`ClapFinder/Views/`) | Scene, animations, progress binding, routing to Home. |

**SDK placement rule:** GoogleMobileAds (SPM, v12.x) is a dependency
of the **app target only** (`project.yml`). It must NOT be added to
`ClapFinderKit/Package.swift` — the GMA binary is iOS-only and would
break `swift build` / `swift test` on macOS CLI, which is how this
repo runs its test suite.

**Info.plist:** `GADApplicationIdentifier` (Google test app ID with a
clearly-marked `PLACEHOLDER` comment for the PM-provided production
ID) + standard `SKAdNetworkItems` list. Test App Open ad-unit ID in
one constants file with the same placeholder convention.

Commit order: `docs:` (this file, EVENTS.md, DESIGN.md amendment,
PLAN.md row) → `chore:` (GMA SDK integration) → `code:` →
`tests:`.

---

## 10. Testing

**Unit (ClapFinderKit, CLI-runnable):**
- `AppOpenAdPolicy`: first-launch suppression; 4 h interval (clock
  injection — t+3:59 denied, t+4:01 allowed); 1-per-session; cold vs
  warm launch flag.
- `SplashStateMachine`: every path in §7 — happy ad path, fail,
  timeout, ineligible, background-freeze/resume idempotence (resume
  event must not re-enter `requesting`), late-ad-after-timeout
  discarded.
- Progress function: monotonicity, never 100% before min-timer,
  always 100% by timeout.

**Device QA (MIGRATION_VALIDATION.md rows, gate merge):**
- Real ad load + present with test IDs.
- Timeout path: airplane mode → splash exits at 5 s without ad.
- First-launch path: fresh install → no ad, no disclaimer.

---

## 11. Deferred / out of scope

- **Onboarding flow** — does not exist yet in this codebase. First
  launch goes splash → Home. A mic-permission education screen is a
  separate future PR; when it lands, rule 2's first-launch path
  becomes splash → onboarding → Home (still no ad).
- Warm-resume app open ads (data-driven decision later).
- Custom (non-emoji) splash illustrations.
- Banner + interstitial placements (separate PR per PLAN.md).
- Production AdMob IDs (PM-provided secret, placeholders marked).
