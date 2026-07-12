# SOUNDS_LICENSES.md — alert-sound sources & licenses

The 8 non-animal alert sounds were replaced at pivot P3 (2026-07-08), then
PM-tuned by ear over two pick rounds. Sources & licenses:

- **Mixkit** (Envato) — Mixkit Sound Effects Free License: free for commercial
  and non-commercial use in audiovisual/interactive projects, no attribution,
  no standalone redistribution. https://mixkit.co/license/#sfxFree
- **Pixabay** — Pixabay Content License: free for commercial use, no
  attribution required, no standalone redistribution.
  https://pixabay.com/service/license-summary/

Files converted to mono 16-bit 44.1 kHz CAF (`ffmpeg` + `afconvert`), trimmed
to ≤ 6 s.

| App file | Mixkit title | Source URL |
|---|---|---|
| `siren.caf` | Ambulance siren US (#1642) — PM pick round 1, replaces #1643 | https://assets.mixkit.co/active_storage/sfx/1642/1642.wav |
| `alarm_clock.caf` | Digital clock digital alarm buzzer (#992) — PM pick round 1, replaces #1003 | https://assets.mixkit.co/active_storage/sfx/992/992.wav |
| `air_horn.caf` | **Pixabay**: Air Horn by Waitwhatimsignedin (#273892) — PM pick round 2 | https://pixabay.com/sound-effects/film-special-effects-air-horn-273892/ |
| `bell.caf` | Church bell calling (#603) — PM pick round 1, replaces #933 | https://assets.mixkit.co/active_storage/sfx/603/603.wav |
| `whistle.caf` | **Pixabay**: Referee/Coach/Sports Whistle by framptones (#291816) — PM pick round 2 | https://pixabay.com/sound-effects/film-special-effects-referee-whistle-coach-whistle-sports-whistle-291816/ |
| `beep.caf` | **Pixabay**: Alarm beep by freesound_community (#34359) — PM pick round 2 | https://pixabay.com/sound-effects/film-special-effects-alarm-beep-34359/ |
| `doorbell.caf` | **Pixabay**: Doorbell Ding Dong by DRAGON-STUDIO (#482879) — PM pick round 2 | https://pixabay.com/sound-effects/household-doorbell-ding-dong-482879/ |
| `foghorn.caf` | Warfare horn (#2289) — deep horn, nearest equivalent to a foghorn. **PM may swap.** | https://assets.mixkit.co/active_storage/sfx/2289/2289.wav |
| `arm_chirp.caf` | **Pixabay**: Old Maruti car unlock sound keyless entry beep by arunangshubanerjee (#327691) — trimmed to the double 1 kHz beep (0.03–0.58 s, fade-out); UI feedback chirp, same on arm and disarm (PM ruling 2026-07-12) | https://pixabay.com/sound-effects/film-special-effects-old-maruti-car-unlock-sound-keyless-entry-beep-327691/ |

The 8 animal sounds (`dog_bark`, `cat_meow`, `cow_moo`, `frog_ribbit`,
`duck_quack`, `pig_oink`, `rooster_crow`, `sheep_baa`) are untouched
(pre-existing synthesized assets).
