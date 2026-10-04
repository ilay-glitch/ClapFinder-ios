# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project

**Guard Dog — Don't Touch My Phone**, Android. An anti-theft deterrent with a
cartoon guard-dog mascot: arm a guard, and if the phone is moved (Don't Touch) or
pulled out of a pocket (Pocket Mode), it screams the chosen alarm sound until the
owner taps DISARM. Free + ads (AdMob app open + interstitial, no banner).

This branch (`android`) is a rewrite of the iOS app on `main`, built from the
behavior spec in `ANDROID_HANDOFF.md` — not a line-by-line port.

| Item | Value |
|------|-------|
| Application ID | `com.appcentral.guarddog` (debug: `.debug` suffix) |
| minSdk / targetSdk / compileSdk | 26 / 36 / 37 |
| Stack | Kotlin 2.3, Jetpack Compose (Material 3), AGP 9.4, Gradle 9.7 |

## Commands

```bash
# Unit tests (pure Kotlin core — state machines and ad policies)
./gradlew :core:test

# Debug APK
./gradlew :app:assembleDebug

# Lint (run before every PR)
./gradlew :app:lintDebug

# Install + launch on a connected device/emulator
./gradlew :app:installDebug && adb shell am start -n com.appcentral.guarddog.debug/com.appcentral.guarddog.MainActivity

# Analytics events stream to logcat until a real SDK lands
adb logcat -s GuardDogAnalytics
```

Builds need JDK 17+ (`JAVA_HOME`) and `local.properties` with `sdk.dir`.

## Architecture

**`core/`** — pure Kotlin/JVM, no Android imports. Every rule with timing in it
takes the clock as a parameter, so tests never sleep.

| File | Responsibility |
|------|----------------|
| `TouchGuardLogic` | Don't Touch: disarmed → grace (5 s) → monitoring → alarming; 2-consecutive-sample trigger |
| `PocketGuardLogic` | Pocket: awaitingPocket → monitoring → alarming; 1.5 s cover / 0.5 s uncover debounces |
| `Sensitivity`, `GuardCatalog` | Thresholds (g) and the 16 alarm voices + chirp |
| `AppOpenAdPolicy`, `SplashStateMachine` | Cold-launch app open ad rules, 1.5 s min / 5 s timeout |
| `InterstitialPolicy`, `InterstitialCounter` | "Use" counting, 3–5 threshold, never while armed |
| `Analytics` | Event names/params — the contract in `EVENTS.md` |

**`app/`** — everything platform-bound.

| Package | Responsibility |
|---------|----------------|
| `guard/GuardEngine` | Process-wide owner of both modes: sensors, alarm, chirps, notifications, mode exclusivity, fail-loud stand-down |
| `guard/GuardService` | Foreground service (`specialUse`) + partial wake lock + ongoing status notification with Disarm |
| `guard/Sensors` | 10 Hz linear-acceleration magnitude; proximity covered edges (wake-up sensor preferred) |
| `alarm/AlarmResponder` | Looping sound on the ALARM stream at max volume, torch pulse, haptics, chirp |
| `ads/AdsManager` | UMP consent → MobileAds init, app open + interstitial |
| `data/Prefs` | All persisted state (SharedPreferences) |
| `ui/` | Compose screens: splash, onboarding, two tabs, alarm overlay. Tokens in `ui/theme/Theme.kt` |

## Conventions

- Branching: `android/pr-{N}-{kebab-case}` off `android`. Commit prefixes: `docs:`, `code:`, `tests:`, `chore:`, `fix:`. Doc commits land before code commits on the same branch.
- Pause and surface under-specced areas. Never expand scope silently.
- Color literals live only in `ui/theme/Theme.kt` (and `res/values/colors.xml` for XML-only surfaces).
- User-visible strings live in `res/values/strings.xml`. Copy source of truth: `ANDROID_HANDOFF.md` §1.6.
- New timing rules go into `core/` as pure logic with a test, never inline in the engine.

## Canonical docs

- `ANDROID_HANDOFF.md` — behavior spec, assets, monetization rules, the re-probe list
- `ANDROID_PORT.md` — what this implementation decided, deviations from iOS, and open probes
- `EVENTS.md` — analytics schema
- `ADS_DESIGN.md`, `SPLASH_DESIGN.md`, `ONBOARDING_DESIGN.md`, `TOUCH_ALERT_DESIGN.md`, `POCKET_MODE_DESIGN.md`, `DESIGN.md` — product/design records inherited from iOS (their code references are iOS-specific)
