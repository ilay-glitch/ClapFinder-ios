# EVENTS.md — Analytics Schema

Canonical event schema for ClapFinder. Doc-leads-code: events are
defined here before any code emits them.

**Transport:** `AnalyticsClient` protocol (`ClapFinderKitAds`) with an
OSLog-backed default (`OSLogAnalyticsClient`). The Firebase adapter
conforms to the same protocol when the analytics PR lands — event
names and params here are written to be Firebase-compatible
(snake_case, ≤ 40 chars, params ≤ 25 per event).

---

## Splash / App Open Ad (PR-10)

| Event | Params | Fired when |
|---|---|---|
| `splash_shown` | `cold_launch: Bool`, `first_launch: Bool` | Splash appears |
| `app_open_ad_requested` | `att_authorized: Bool` | Eligibility passed, SDK request sent |
| `app_open_ad_shown` | — | Ad presented full-screen |
| `app_open_ad_failed` | `error_reason: String` | SDK returned a load/present error |
| `app_open_ad_timeout` | `elapsed_ms: Int` | 5 s ceiling hit before load |
| `splash_completed` | `duration_ms: Int`, `ad_shown: Bool`, `ad_skip_reason: String` | Splash hands off to Home |

### `ad_skip_reason` enum

Distinguishes fill problems from caps working as designed:

| Value | Meaning |
|---|---|
| `none` | Ad was shown |
| `first_launch` | First-ever launch — no request made (policy rule 2) |
| `frequency_cap` | < 4 h since last app open ad (rule 4) |
| `session_cap` | Already shown this session (rule 3) |
| `load_failed` | Request made, SDK error |
| `timeout` | Request made, not loaded within 5 s |

---

## Touch / Motion Alert (PR-11 — TOUCH_ALERT_DESIGN.md §8)

| Event | Params | Fired when |
|---|---|---|
| `touch_alert_armed` | `sensitivity: String` | Arm button tapped (grace period starts) |
| `touch_alert_triggered` | `sensitivity: String`, `grace_elapsed_s: Int` | Motion above threshold fires the alarm |
| `touch_alert_disarmed` | `sensitivity: String`, `was_alarming: Bool`, `armed_duration_s: Int` | Disarm button tapped |

---

## Banner / Interstitial (PR-12 — ADS_DESIGN.md)

| Event | Params | Fired when |
|---|---|---|
| `banner_loaded` | — | Banner ad fills |
| `banner_failed` | `error_reason: String` | Banner request errors |
| `interstitial_shown` | `uses_since_last: Int` | Interstitial presents (counter resets) |
| `interstitial_suppressed` | `reason: String` | Eligible moment skipped: `detection_active` / `alarm_active` / `frequency_cap` / `not_loaded` |

---

## Reserved (future PRs — do not emit yet)

- Detection funnel: `listening_started`, `listening_stopped`,
  `clap_detected` — detection feature analytics, own doc round first.
- Attribution events — Adjust PR.
