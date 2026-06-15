# LIVE_ACTIVITY_DESIGN.md — Touch-Alert Live Activity (disarm from outside the app)

**Version:** v2 — PM-approved 2026-06-11, decisions folded
**PR:** logical PR-13 (touch-alert add-on)
**Goal:** While the shield is armed/alarming, show a Lock Screen +
Dynamic Island Live Activity with a **Disarm** button, so the user can
stop it without unlocking into the app.

---

## 1. Why Live Activity (PM ruling 2026-06-11)

Chosen over a notification-action button. A Live Activity persists on
the Lock Screen the whole time the shield is armed (not just when a
notification happens to be showing), and gives a real interactive
Disarm button in both the Lock Screen card and the Dynamic Island —
the right model for an always-on anti-theft state.

---

## 2. Architecture

| Piece | Where | Responsibility |
|---|---|---|
| `TouchAlertActivityAttributes` | **new shared module** `ClapFinderKitActivity` (imported by both the app and the widget extension) | The `ActivityAttributes` + `ContentState` (armed vs alarming, animal emoji). Must be visible to both targets — hence its own tiny module, not the app target. |
| `ClapFinderWidgets` extension | **new app-extension target** | The Live Activity UI: Lock Screen view + Dynamic Island (compact / expanded / minimal). Renders state; hosts the Disarm button. |
| `DisarmIntent` | shared (app + extension) | `LiveActivityIntent` (iOS 17+). Its `perform()` runs **in the app process** and calls the live `TouchAlertCoordinator` to disarm. |
| `TouchAlertCoordinator` | `ClapFinderKitMotion` (existing) | Gains ActivityKit lifecycle: **start** the activity on arm, **update** it to `.alarming` on trigger, **end** it on disarm. |

**Disarm wiring (the tricky part, solved):** when the shield is
armed/alarming the **app process is alive** (the audio-session
keep-alive, §4 of TOUCH_ALERT_DESIGN). So `DisarmIntent.perform()`
(running in-process via `LiveActivityIntent`) can reach the live
coordinator through a lightweight main-actor registry
(`TouchAlertCoordinator.current`), call `disarm()`, and the running
alarm stops directly. No App Group / Darwin-notification dance needed
because we are never disarming a dead process.

---

## 3. Lifecycle

```
arm()      → Activity.request(state: .grace/.armed)      [Live Activity appears]
trigger    → activity.update(state: .alarming)           [card flips to "Motion detected!"]
disarm()   → activity.end(dismissalPolicy: .immediate)   [card disappears]
  ↑ called either from the in-app DISARM button OR the Live Activity's DisarmIntent
```

ActivityKit updates here are **local** (started/updated/ended by the
running app) — **no push notifications, no APNs**, so no paid-account
push dependency.

## 4. UI (per DESIGN tokens, brand gradient)

- **Lock Screen card:** shield/animal emoji + status ("Armed — don't
  touch" / "Motion detected!") + **Disarm** button.
- **Dynamic Island:** compact = shield icon; expanded = status +
  Disarm; minimal = shield dot.
- Strings via `Localizable.strings`.

## 5. Constraints / risks (flagged, to verify on device)

1. **Free Apple account:** a second target = a second App ID. Free
   accounts cap App IDs (≈10/week) and active apps (3). Adding the
   widget extension should fit, but **must be verified on-device** —
   if it blocks, the fallback is the notification-action button
   (the option-(b) we deferred).
2. **`NSSupportsLiveActivities = YES`** added to the app Info.plist.
3. **iOS 17+** for the interactive `LiveActivityIntent` disarm button.
   Deployment target is already 17.0 ✅.
4. **Simulator:** Live Activities render in the simulator, but the
   real Lock-Screen + Dynamic Island behavior is **device QA**.
5. **xcodegen:** the new extension target + its Info.plist
   (`NSExtensionPointIdentifier = com.apple.widgetkit-extension`) are
   defined in `project.yml` so regeneration keeps them.

## 6. Testing

- Unit (CLI): `ContentState` transitions (grace→armed→alarming),
  `DisarmIntent` calls `coordinator.disarm()` via the registry.
- Device QA rows (consolidated pass): activity appears on arm; flips
  to alarming on motion; **Disarm from Lock Screen stops sound +
  flash + vibration**; activity ends on disarm; survives screen lock.

## 7. Files + diff estimate

| File | ~LOC |
|---|---|
| `ClapFinderKitActivity` module (attributes + DisarmIntent + registry) | 90 |
| `ClapFinderWidgets` extension (Live Activity views) | 180 |
| `TouchAlertCoordinator` ActivityKit lifecycle | 70 |
| `project.yml` extension target + Info.plist + `NSSupportsLiveActivities` | 60 |
| `Localizable.strings` | 10 |
| Tests | 80 |

**≈ 490 LOC, 1 new module + 1 new extension target.**

## 8. Decisions (RULED — PM 2026-06-11)

1. **Activity lifetime — RULED: whole time armed** (grace + monitoring +
   alarming), so the user can disarm before a false trigger too.
2. **Dynamic Island Disarm — RULED: expanded island only** (standard).
3. **PLAN.md — RULED: logical PR-13**; ads/analytics ladder shifts by one
   (banner/interstitial → PR-14, Firebase → PR-15, …).
