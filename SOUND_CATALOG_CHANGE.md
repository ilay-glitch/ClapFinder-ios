# SOUND_CATALOG_CHANGE.md — Real-World Alert Sounds

**Version:** v1 — PM-approved 2026-06-15
**PR:** logical PR-14 `phase2/pr-14-realworld-sounds`
**Goal:** The app is no longer animals-only. Keep the 8 real Boomr animal
sounds (our friendly differentiator) and replace the 8 synthesized animal
placeholders with the 8 real-world alert sounds the find-my-phone category
expects (loud, locate-from-another-room).

---

## 1. Catalog change (16 → 16)

**KEEP** (real Boomr audio, unchanged): dog, cat, cow, frog, duck, pig,
rooster, sheep.

**REMOVE** (synthesized placeholders): lion, elephant, monkey, fox, wolf,
parrot, dolphin, bee — and delete their `.caf` files.

**ADD** (8 real-world alerts):

| id | name | emoji | soundFile |
|---|---|---|---|
| siren | Siren | 🚨 | siren.caf |
| alarm_clock | Alarm Clock | ⏰ | alarm_clock.caf |
| air_horn | Air Horn | 📢 | air_horn.caf |
| bell | Bell | 🔔 | bell.caf |
| whistle | Whistle | 🎵 | whistle.caf |
| beep | Beeper | 🔊 | beep.caf |
| doorbell | Doorbell | 🚪 | doorbell.caf |
| foghorn | Foghorn | 🚢 | foghorn.caf |

Catalog order: 8 animals first, then 8 alerts. Grid stays 4×4, 16 items.

## 2. Decisions (PM-ruled 2026-06-15)

1. **Default selected sound → `siren`** (global). Both clap and touch-alert
   modes share one selection (`CatalogStore.selectedAnimalID`); the stored
   default changes from `dog` to `siren`. A siren is the natural anchor for
   an anti-theft alarm and a strong locate sound for clap too.
2. **Names live in `catalog.json` (English).** This matches the existing
   pattern — names are catalog data, not `Localizable.strings` entries.
   **The app is English-only; no Hebrew localization is added** (none exists
   anywhere in the project; localizing 8 sounds in isolation would be
   inconsistent — a full i18n pass is a separate future effort).
3. **The model type stays `Animal`.** It now holds non-animal sounds too.
   Renaming `Animal`→`Sound` is a large cross-module churn (Audio, Motion,
   Activity, Views, tests) — deferred as optional naming debt; not worth the
   risk in this PR. User-facing labels are already generic
   (`animals.header` = "Choose a sound").

## 3. Audio sourcing

- **Generate our own** loud, distinct synthesized versions (siren = wail
  sweep, doorbell = two descending tones, bell = decaying harmonics,
  foghorn = low fundamental, etc.). Do NOT copy competitor audio.
- Peak-amplitude verified (> 24k / 32767), filenames match catalog ids.
- **TestFlight blocker:** real licensed audio for all 8 new alert sounds —
  recorded in MIGRATION_VALIDATION.md, same as the original animal stand-ins.

## 4. Safety / no-regression (verified pre-write)

- `CatalogStore` already resets to the first catalog item if a persisted id
  is missing — a user who had selected a removed animal lands safely.
- No enum / allowlist hard-codes animal ids anywhere; new ids flow through.
- 4×4 grid is fixed-column in HomeView — 16 items unchanged.

## 5. Files + diff estimate

| File | Change | ~LOC |
|---|---|---|
| `SOUND_CATALOG_CHANGE.md` | new (doc commit) | 70 |
| `catalog.json` | −8 animals, +8 alerts | 16 |
| `CatalogStore.swift` | default id `dog` → `siren` | 2 |
| `Resources/Audio/*.caf` | delete 8, add 8 (generated) | — |
| tests | catalog: 16 unique ids + every file non-silent | 40 |
| `MIGRATION_VALIDATION.md` | TestFlight blocker + 8 QA rows | 20 |

**≈ 150 LOC + asset swap. No UI-layout or pipeline code change.**

## 6. Testing

- Unit: catalog loads 16 entries, ids unique, every referenced `.caf`
  exists and is non-silent (peak > threshold) — as a test.
- Device QA: each of the 8 new sounds plays at full volume + silent-switch
  override (both clap and touch-alert modes).
