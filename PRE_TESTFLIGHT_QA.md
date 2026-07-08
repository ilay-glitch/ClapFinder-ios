# PRE_TESTFLIGHT_QA.md — Guard Dog, consolidated pre-TestFlight checklist

One pass on a real device before the first TestFlight build. Consolidates the
pivot-era gates. **Already passed on-device:** guard core M1–M8
(MIGRATION_VALIDATION.md, PM 2026-07-08 — no mic prompt, lock-screen survival,
alarm on touch).

## A. Fresh-install path
| # | Check | Expected |
|---|---|---|
| A1 | Cold launch | Splash (sky, guard hero art, tagline "Nobody touches your phone. Ever.") → onboarding |
| A2 | Onboarding 3 steps | guard intro (wave art) → notification explainer → system notif prompt → "Ready to stand guard." → Home |
| A3 | No mic prompt anywhere | Never — the permission no longer exists |
| A4 | ATT prompt | After onboarding → Home, ~0.5 s; never overlapping the notif prompt |
| A5 | No App Open Ad on first launch | Existing rule holds |

## B. Returning-user path
| # | Check | Expected |
|---|---|---|
| B1 | Relaunch | Splash → Home directly (no onboarding) |
| B2 | App Open Ad | Eligible per policy (≥4 h, ≤1/session); ATT already determined |

## C. Guard flows (core — re-verify quickly; deep pass = M1–M8 ✅)
| # | Check | Expected |
|---|---|---|
| C1 | Arm → grace → monitoring | "Tap to activate" → 5 s grace → armed |
| C2 | Touch while armed | Alarm: sound loops + flashlight + overlay; DISARM stops everything |
| C3 | Lock-screen guard | M2 ✅ (re-spot-check) |
| C4 | Live Activity | Armed state on Lock Screen / Dynamic Island; disarm button works |
| C5 | Watchdog | M6 ✅ |

## D. New sounds (Mixkit, SOUNDS_LICENSES.md)
| # | Check | Expected |
|---|---|---|
| D1 | Each of the 8 alert sounds | Select each guard → arm → trigger → correct, audible, loops cleanly (siren, alarm_clock, air_horn*, bell, whistle, beep, doorbell, foghorn*) — *nearest-equivalents flagged for possible swap |
| D2 | Animal sounds | Unchanged, still play |

## E. New art (once P3 assets land)
| # | Check | Expected |
|---|---|---|
| E1 | App icon | Guard icon, full-bleed, no black corners |
| E2 | Home | Background art behind UI, content readable, cards white, 60 fps scroll |
| E3 | Hero mascot | Shield (idle) ↔ watching (armed) swap |
| E4 | Alarm overlay | Barking art replaces emoji |
| E5 | Onboarding/splash | Guard poses render (no detective art left visible) |

## F. Monetization moments
| # | Check | Expected |
|---|---|---|
| F1 | Banner | Home bottom, disarmed only; hidden while armed/alarming |
| F2 | Interstitial (D1-v2) | Arm → monitoring → user disarm → back on Home → attempt may fire (test IDs). Never during arm, alarm, or alarm-dismiss |
| F3 | App Open | Cold launch, returning user, ≥4 h gap |

## G. Identity
| # | Check | Expected |
|---|---|---|
| G1 | Icon label | "Guard Dog" |
| G2 | Bundle | com.appcentral.guarddog (+ .widgets); installs as a NEW app |
| G3 | Copy sweep | No "ClapFinder"/clap wording anywhere user-visible |
