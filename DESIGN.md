# DESIGN.md — ClapFinder visual system

**Version:** v-next (sky-blue redesign) — **LOCKED 2026-06-21**
**Supersedes:** v3 (dark purple→pink→orange). See §10 change log.

---

## 1. Brand direction

Bright, cheerful, trustworthy. A sunny **sky-blue** stage for a friendly 3D
detective-dog mascot. Content lives on **white / cream cards**; sky-blue is the
ambient backdrop and accent only — text never sits directly on the sky-blue.
Typeface stays **SF Rounded**. Flat, solid CTAs (no gradients).

> **Inverts v3.** v3 was dark-on-dark (white text on near-black). v-next is
> dark-on-light: navy text on white/cream surfaces, over a sky-blue field.

## 2. Color tokens

Hex literals live **only** in `ClapFinderKitDesign`. All other modules reference
`CFColor.*`. Because views consume tokens (not raw hex), re-pointing the tokens
re-skins the app — only two views hold direct raw-anchor refs (see §10).

| Swift name | Value | Usage |
|------------|-------|-------|
| `CFColor.skyPrimary` | `#5BB8FF` | **Screen background** (ambient field) — the value all full-scene character art is normalised to (§9) |
| `CFColor.skyTint` | `#A8DCFF` | Lighter sky — ring gradients, section tints |
| `CFColor.surface` | `#FFFFFF` | Cards, sheets, nav, ad container |
| `CFColor.cream` | `#F5EEE0` | Warm accent surface (alt cards, callouts) |
| `CFColor.ctaBlue` | `#2D7FF9` | Primary buttons / Continue (flat, solid) |
| `CFColor.surfaceCard` | `#FFFFFF` | Card fill; pair with a soft shadow |
| `CFColor.borderSubtle` | navy `#14233D` @ 0.10 | Dividers, card borders on light |
| `CFColor.textPrimary` | navy `#14233D` | Primary text on light surfaces (AA/AAA, §8) |
| `CFColor.textSecondary` | navy @ 0.60 | Secondary text |
| `CFColor.textTertiary` | navy @ 0.40 | Placeholders |
| `CFColor.listeningActive` | `#22C55E` | "Listening" green (unchanged) |
| `CFColor.celebrationCyan` | `#22D3EE` | "Found!" flash (unchanged) |
| `CFColor.adContainer` | `#FFFFFF` | Banner container on light bg |

**Deprecated (kept defined, not deleted; unreferenced after the full redesign):**
`backgroundPrimary` → use `skyPrimary`; `backgroundElevated` → use `surface`;
`gradientStart` `#8B5CF6`, `gradientMid` `#EC4899`, `gradientEnd` `#F97316`; and
all `splash*` tokens. Each carries a `// deprecated: redesign v-next` comment.
(The splash still references `splash*` until Part B rebuilds it — those refs are
removed there, not here.)

### Legibility rule (PM ruling a)
Body and interactive content **never** sit directly on `skyPrimary` — always on
`surface` (white) or `cream`. Sky-blue is backdrop + accents only.

## 3. Typography (unchanged — SF Rounded)

| Token | Size | Weight | Usage |
|-------|------|--------|-------|
| `CFFont.display()` | 34 | Bold | App title |
| `CFFont.title1()` | 28 | Bold | Section headers |
| `CFFont.title2()` | 22 | Semibold | Card titles |
| `CFFont.headline()` | 17 | Semibold | Row labels, selected name |
| `CFFont.body()` | 16 | Regular | Body copy |
| `CFFont.callout()` | 15 | Regular | Hints |
| `CFFont.caption()` | 12 | Regular | Grid labels |

## 4. Shape tokens (unchanged)

`CFRadius`: card 20 · button 16 · animalCard 14 · toggle 36.

## 5. Spacing (unchanged — 8 pt grid)

`CFSpacing`: xs 4 · sm 8 · md 16 · lg 24 · xl 32 · xxl 48.

## 6. Gradients

Brand gradients are **redefined** to the blue family; consumers (toggle,
selected card border, sensitivity, mode switcher, alarm button, touch hero,
pulse rings) inherit the new look with no view edits.

| Token | v-next composition | Usage |
|-------|--------------------|-------|
| `CFGradient.brand` | **solid `ctaBlue`** (1-stop) | Buttons, active states, selected borders |
| `CFGradient.pulse` | `skyTint`→`ctaBlue` | Pulse / radar rings |
| `CFGradient.brandHorizontal` | `skyPrimary`→`ctaBlue` (leading→trailing) | Sensitivity active segment |
| `CFGradient.splashNight` / `titleGold` / `splashBar` | **DEPRECATED** | Splash rebuilt (Part B) |

> CTA ruling (b): **flat solid `ctaBlue`**. `brand` is kept as a token for the
> active-state consumers but resolves to solid `ctaBlue`.

## 7. Key components (re-skin only — behaviour unchanged)

- **Listening toggle:** white circle on the sky field; active = `ctaBlue` fill,
  `pulse` radar rings. Mascot wave accent (~64 pt) may sit top-trailing on Home.
- **Animal grid card:** `surface` white card, `borderSubtle`; selected =
  `ctaBlue` border + faint `skyTint` inner glow (replaces the violet glow at the
  `AnimalCardView` raw-anchor ref).
- **Sensitivity / mode switcher:** active segment `ctaBlue`; track `cream`/white.
- **Banner ad:** 50 pt, full width, bottom-anchored, `adContainer` white to sit
  cleanly on the light field (ADS_DESIGN.md D3 layout unchanged).

## 8. Accessibility

- **Contrast (validated, ruling b — kids/All-Ages, no flex):** `textPrimary`
  `#14233D` measures **15.70:1 on white**, **13.60:1 on cream** — both AA & AAA.
  (7.29:1 even on sky, though content never sits there.)
- `accessibilityReduceMotion` still gates splash/pulse animation.
- Mascot art is decorative → `.accessibilityHidden(true)`; labels carry meaning.

## 9. Character assets — one standardised blue (PM ruling c)

Five 1254² PNGs. Sampling their baked backgrounds showed the blues **do not
cluster** (`_searching` `#4BACFC`, `_phone` `#51ADFC`, `_wave` `#59B3FD`; `_icon`
& `_avatar` have opaque **black** corners). Locked handling:

| Asset | Handling |
|-------|----------|
| `_searching`, `_phone`, `_wave` | **flood-normalise background to `skyPrimary` `#5BB8FF`** (flat-region replace, not a fur cutout) |
| `_icon` | flood-fill black corners → `skyPrimary`, full-bleed, opaque → **App Icon** (Part A) |
| `_avatar` | circle-mask (clips black corners); deeper interior reads as an intentional badge |

`skyPrimary` = `#5BB8FF` is **locked**; all three full-scene blues normalise to
it. No fur-edge cutouts anywhere.

## 10. Change log

| Date | Version | Change |
|------|---------|--------|
| 2026-06-09 | v3 | Dark purple→pink→orange system signed off. |
| 2026-06-21 | v-next | **Sky-blue redesign — LOCKED.** Light theme, dark-on-light text (`#14233D`, AA/AAA verified), flat `ctaBlue` CTAs, detective-dog mascot. Brand gradients re-pointed to blue; `backgroundPrimary`/`backgroundElevated`/violet-pink-orange/splash tokens deprecated. Two direct raw-anchor refs repointed (`AnimalCardView`, `ClapCalibrationSheet`). |
