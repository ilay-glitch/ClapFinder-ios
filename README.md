# Guard Dog — Don't Touch My Phone (Android)

Arm the guard dog; if anyone moves your phone, or pulls it out of your pocket, it
barks (or sirens, or moos) at full volume and flashes the torch until you disarm.

- **Don't Touch** — set the phone down, 5 s to walk away, then any movement trips the alarm.
- **Pocket Mode** — slide the phone into a pocket; pulling it out trips the alarm.

## Build

Requirements: JDK 17+, Android SDK with platform 37.

```bash
echo "sdk.dir=$HOME/Library/Android/sdk" > local.properties
./gradlew :core:test :app:assembleDebug
```

See `CLAUDE.md` for architecture and conventions, and `ANDROID_PORT.md` for the
status of each platform decision.

> **Before release:** replace the AdMob test IDs in `app/build.gradle.kts` with
> Android's own app and ad-unit IDs, and run the on-device probe gate in
> `ANDROID_PORT.md`.
