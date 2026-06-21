# ONBOARDING_DESIGN.md — First-launch onboarding

**Version:** v1 — **IMPLEMENTED 2026-06-21** (redesign Part C,
`phase3/pr-24-onboarding`). Copy is the baseline; tune wording on-device.
**Closes:** the deferred-onboarding note in SPLASH_DESIGN.md.

A 3-step, first-launch-only guided intro built around the detective-dog mascot,
inserted between splash and Home. Includes the pre-permission mic explainer we
deferred earlier.

---

## 1. Routing & the first-launch flag (fence-safe)

The ad's first-launch flag (`appOpenAd.hasCompletedFirstLaunch`, owned by
`SplashViewModel`) is **not reused** — onboarding gets its **own** flag so the
App Open Ad fence is untouched.

```
New flag:  UserDefaults "onboarding.hasCompleted" (Bool)

First launch  (onboarding.hasCompleted == false):
    splash  →  Onboarding (3 steps)  →  Home
    (App Open Ad already suppressed on first launch by the existing rule)
    set onboarding.hasCompleted = true at step 3 → Home

Returning  (onboarding.hasCompleted == true):
    splash  →  Home          (exactly as today)
```

`ClapFinderApp` gains one gate after splash: route to `OnboardingView` iff
`!onboarding.hasCompleted`, else `HomeView`. Splash still sets
`appOpenAd.hasCompletedFirstLaunch` as today — the two flags are independent.

## 2. Steps

| Step | Purpose | Asset | Copy (baseline) |
|------|---------|-------|-----------------|
| **1 — Welcome** | what the app does | `detective_dog_wave` | **Title:** "Hi, I'm on the case!"  **Body:** "To find your phone, just clap twice 👏"  **CTA:** Continue |
| **2 — Mic education → permission** | pre-permission explainer, then the system prompt | mic + sound-wave rings, `_avatar` badge | **Title:** "I listen for your clap"  **Body:** "Only listens for claps · Your privacy matters 🔒"  **CTA:** "Enable Microphone" |
| **3 — Ready** | hand off to Home | `detective_dog_phone` | **Title:** "All set!"  **Body:** "Let's test it — give it a clap."  **CTA:** "Start" |

- "STEP n OF 3" indicator at top; Continue/CTA buttons flat `ctaBlue`.
- White/cream card content over the sky-blue field (DESIGN.md legibility rule).
- Mascot `_avatar` shown as a circular blue badge beside a white speech bubble.

## 3. Mic permission ordering (the key sequence)

Step 2 **is** the pre-permission explainer (mirrors the existing
`touch.notifExplainer` pattern). Order:

1. Step 2 screen explains *why* (privacy reassurance) — no system dialog yet.
2. Tap **"Enable Microphone"** → `AVAudioApplication.requestRecordPermission`
   (iOS 17+) — the system dialog now appears, context already set.
3. **Grant or deny → proceed to Step 3 regardless.** Denial is not fatal: the
   detector already requests mic lazily on first listen, and a denied user can
   re-enable in Settings (existing behaviour; no new Settings UI in this PR).

Additive — `ClapDetector` is not touched; onboarding only requests earlier with
a friendlier explainer.

## 4. ATT relocation (PM ruling d)

ATT must never overlap the mic prompt. Same rule (never cold launch, never over
the ad, after the first-launch handoff) — relocated:

```
First launch:  … Step 2 mic prompt (responds) → Step 3 → Home → ATT (~0.5s)
Returning:     splash → Home → ATT (~0.5s)        (unchanged)
```

The ATT trigger moves from "after splash→Home" to "after the final transition
*into* Home" (on first launch, after onboarding). `requestATTIfNeeded` stays
idempotent; only its call site shifts.

## 5. QA rows (append to MIGRATION_VALIDATION.md)

| # | Scenario | Expected |
|---|----------|----------|
| O1 | Fresh install → launch | splash → onboarding step 1 |
| O2 | Step 2 "Enable Microphone" | system mic prompt appears once |
| O3 | **Fresh install: mic prompt (step 2) & ATT prompt (after step 3→Home) never overlap** | two distinct, sequential prompts |
| O4 | Complete onboarding, relaunch | splash → Home directly (no onboarding) |
| O5 | First launch | no App Open Ad (existing rule still holds) |
| O6 | Deny mic in step 2 | onboarding still completes; first listen re-prompts / Settings |

## 6. Strings (new `onboarding.*` keys)

`onboarding.step1.title/body`, `onboarding.step2.title/body/cta`,
`onboarding.step3.title/body/cta`, `onboarding.continue`,
`onboarding.progress` ("STEP %d OF 3"). Baseline copy in §2; tuned on-device.

## 7. Fences

- No detection / `ClapDetector` / `ClapSpectral` changes (mic via standard API).
- No splash *logic* change — only the post-splash route gains the onboarding
  branch; `SplashStateMachine` / `AppOpenAd*` untouched.
- No monetization-policy change — first-launch ad suppression already covers the
  onboarding path; ad flag independent of `onboarding.hasCompleted`.
