# ANDROID_PORT.md — implementation record

What the Android build decided against `ANDROID_HANDOFF.md`, where it deliberately
differs from iOS, and what still needs a real device. Written 2026-10-04 with the
first full implementation on the `android` branch.

## 1. Verified so far (emulator, API 36)

| Flow | Result |
|---|---|
| Cold launch: system splash → in-app splash → onboarding (3 steps, notification prompt on step 2) → home | ✅ |
| First launch makes no app open ad request (`ad_skip_reason=first_launch`) | ✅ |
| Don't Touch: grace countdown ring 5→1, chirp at monitoring start, emulated motion → alarm | ✅ |
| Alarm: full-screen overlay above the tab bar, Back swallowed, alarm notification posted, audio focus on `USAGE_ALARM` | ✅ |
| DISARM: alarm stops, alarm notification removed, foreground service + ongoing notification gone | ✅ |
| Pocket: 1.5 s cover engages (screen blanks), 0.2 s fabric flicker ignored, 0.5 s uncover alarms | ✅ |
| Completed session → volume tip appears, use counted, interstitial suppressed by `frequency_cap` | ✅ |
| Process killed while armed → next launch posts "Touch Alert stopped" | ✅ |
| `:core:test` (25 tests), `:app:lintDebug` (0 errors), `:app:assembleRelease` (R8 + shrink) | ✅ |
| Release (R8) build installed and run: onboarding, arm → alarm → disarm, pocket engage → alarm → disarm | ✅ |

App open path on the emulator: consent refresh → `app_open_ad_requested` →
`app_open_ad_timeout` at 5 s → home. The UMP refresh alone took ~3.5 s there, so a
test ad never loaded inside the window — measure consent + load latency on real
devices; if it's routinely slow, start the refresh earlier (Application start).

Not verifiable on an emulator: real accelerometer/proximity behavior, torch,
haptics, loudness, screen-off/Doze survival, OEM battery killers, AdMob fill.

## 2. Answers to the handoff's re-probe list (§4) — design chosen, probe still owed

| # | Decision | Probe to run before launch |
|---|---|---|
| 4.1 | Pocket Mode runs in the same foreground service as Don't Touch, with the **wake-up proximity sensor** + partial wake lock, so it can keep sensing with the screen off/locked. While armed it also holds `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, which blanks the screen and disables touch while covered — the Android equivalent of iOS's proximity blank, so pocket fabric can't tap the UI. | Locked-screen proximity events on Pixel, Samsung, Xiaomi; confirm uncover relights the screen into the alarm overlay. |
| 4.2 | Torch pulses (150 ms on / 100 ms off) via `CameraManager.setTorchMode` from the engine, foreground or not. Failures are logged and ignored. | Torch while locked during an alarm on 2–3 OEMs. |
| 4.3 | Not rebuilt — no notification-LED dependency anywhere. | — |
| 4.4 | Foreground service, type `specialUse` (Play Console declaration needed), ongoing notification, partial wake lock for the session. No silent-audio hack, no battery-optimization exemption requested. | Sensor delivery + service survival under Doze / OEM battery managers over 30 min; only then decide on an "ignore battery optimizations" ask. |
| 4.5 | Alarm plays on `USAGE_ALARM`; the ALARM stream is raised to max while alarming, re-asserted every second (volume keys can't silence it), and restored on disarm. Volume-tip copy rewritten to match (`strings.xml` `volume_tip_body`). | Confirm silent/vibrate/DND behavior per OEM, then finalize the tip wording. |
| 4.6 | No settings deep links shipped yet — nothing in v1 needs one. Use real Settings intents when a tip does. | — |

Debounces (1.5 s / 0.5 s) and motion thresholds (0.15 / 0.08 / 0.04 g) are
unchanged from iOS and still need tuning on Android hardware. The motion source
throttles to 10 Hz so "2 consecutive samples" keeps the iOS meaning (~100–200 ms
of movement) on sensors that report faster.

## 3. Deliberate differences from iOS

- **Disarm from the notification requires unlock.** The ongoing notification's
  Disarm action uses `setAuthenticationRequired(true)`; the alarm overlay is not
  shown over the lock screen. A thief can't silence the guard from the shade.
- **Arming waits for the notification-permission answer** (pre-arm explainer path).
  Arming first would let the user's own tap on "Allow" trip the alarm after grace.
- **Fail-loud covers process death**: a persisted session marker found at the next
  launch posts the stand-down notification. Service destruction while armed does
  the same immediately; a sounding alarm is never stood down.
- **Pocket alarm posts no alarm notifications** (iOS parity — only Don't Touch does
  the 0 / +5 / +10 s trio).
- **Consent**: UMP replaces ATT. The consent form is shown on reaching Home; the
  splash refreshes consent (no form) inside the 5 s window before each app open
  request, because UMP forgets the status between processes. No consent →
  `app_open_ad_failed(no_consent)`. `app_open_ad_requested` carries
  `consent_obtained` instead of `att_authorized`.
- **Onboarding step 2** uses the guard dog (watching) instead of the retired
  detective art.
- **Sounds** are lossless FLAC transcodes of the iOS PCM sources (all mono 44.1 kHz,
  stored uncompressed in the APK for `MediaPlayer`); no quality change. Swap in
  re-encodes from the source URLs in `SOUNDS_LICENSES.md` if preferred.

## 4. Before release

1. Create Android AdMob app + ad units; replace the test IDs in `app/build.gradle.kts`.
2. Play Console: `specialUse` foreground-service declaration (text is in the manifest
   property), notification and data-safety forms.
3. Run the §2 probe gate on real devices, then the POCKET_MODE_DESIGN §6 QA list.
4. Signing config + `targetSdk` check against Play's current requirement.
5. Wire a real analytics transport behind `AnalyticsClient` (currently logcat).
