# ClapFinder — Visual & UX System
**Status:** v3 | Signed off
**Audit history:** see bottom

---

## Brand direction
Vibrant, energetic, family-friendly. NOT pastel. Dark background with bold gradient pops. Big emoji, big type, clear hierarchy. The app should feel delightful — kids should want to clap for it.

---

## Color tokens

| Swift name | Hex / Value | Usage |
|------------|-------------|-------|
| `CFColor.backgroundPrimary` | `#0D0818` | Screen background |
| `CFColor.backgroundElevated` | `#1A0F2E` | Elevated surfaces, nav bar |
| `CFColor.surfaceCard` | `rgba(255,255,255,0.07)` | Cards, list rows |
| `CFColor.borderSubtle` | `rgba(255,255,255,0.10)` | Card borders, dividers |
| `CFColor.gradientStart` | `#8B5CF6` | Violet — gradient anchor |
| `CFColor.gradientMid` | `#EC4899` | Pink — gradient mid |
| `CFColor.gradientEnd` | `#F97316` | Orange — gradient end |
| `CFColor.textPrimary` | `#FFFFFF` | Primary labels |
| `CFColor.textSecondary` | `rgba(255,255,255,0.65)` | Secondary labels |
| `CFColor.textTertiary` | `rgba(255,255,255,0.40)` | Placeholders, captions |
| `CFColor.listeningActive` | `#22C55E` | "Listening" green dot |
| `CFColor.celebrationCyan` | `#22D3EE` | "Found!" success state |
| `CFColor.adContainer` | `#1A0F2E` | Banner ad background |
| `CFColor.splashMoonCore` | `#FFF8D6` | Splash moon radial center |
| `CFColor.splashMoonEdge` | `#FFD96B` | Splash moon edge, glow, sound-wave arcs |
| `CFColor.splashHillBack` | `#5C2475` | Splash back hill |
| `CFColor.splashHillFront` | `#471D62` | Splash front hill |

**Rule:** Hex literals only in `ClapFinderKitDesign`. All other modules reference `CFColor.*` tokens.

---

## Typography

Font: SF Rounded — `.system(size:weight:design: .rounded)` in SwiftUI

| Swift name | Size | Weight | Usage |
|------------|------|--------|-------|
| `CFFont.display()` | 34pt | Bold | App title |
| `CFFont.title1()` | 28pt | Bold | Section headers |
| `CFFont.title2()` | 22pt | Semibold | Card titles |
| `CFFont.headline()` | 17pt | Semibold | Animal name (selected) |
| `CFFont.body()` | 16pt | Regular | Body copy |
| `CFFont.callout()` | 15pt | Regular | Supporting text |
| `CFFont.caption()` | 12pt | Regular | Animal grid labels |

---

## Shape tokens

| Swift name | Value | Usage |
|------------|-------|-------|
| `CFRadius.card` | 20pt | Cards, sheets |
| `CFRadius.button` | 16pt | Buttons, chips |
| `CFRadius.animalCard` | 14pt | Animal grid items |
| `CFRadius.toggle` | 36pt | Listening toggle |

---

## Spacing (8pt base grid)

| Swift name | Value |
|------------|-------|
| `CFSpacing.xs` | 4pt |
| `CFSpacing.sm` | 8pt |
| `CFSpacing.md` | 16pt |
| `CFSpacing.lg` | 24pt |
| `CFSpacing.xl` | 32pt |
| `CFSpacing.xxl` | 48pt |

---

## Gradients

| Swift name | Colors | Usage |
|------------|--------|-------|
| `CFGradient.brand` | gradientStart → gradientMid → gradientEnd | Buttons, toggle active, selected borders |
| `CFGradient.pulse` | gradientStart → gradientEnd | Pulse ring strokes |
| `CFGradient.splashNight` | `#2B1055 → #4A1A6B → #7B2D8B → #C44B8C → #F0735A`, stops 0/30/55/78/100% | Splash background ONLY (SPLASH_DESIGN.md §3) |
| `CFGradient.titleGold` | `#FFD96B → #FF9D6B → #FF6BB5` | Splash title text ONLY |
| `CFGradient.splashBar` | `#FFD96B → #FF8A5C → #FF5CA8` | Splash progress fill ONLY |

**Splash scope rule:** `splash*` and `titleGold` tokens are splash-screen-only.
Buttons, toggles, and selected states keep `CFGradient.brand` — the splash
night palette must not leak into app chrome. Hex values are verbatim from
`LOADING_SCREEN_MOCKUP.html` (visual source of truth).

---

## Key components

### Listening toggle
- Diameter: 72pt circle
- Active: `CFGradient.brand` radial fill, white mic icon
- Inactive: white border (2pt), transparent fill, gray mic icon
- Tap: spring animation scale 0.95 → 1.0

### Pulse rings (listening state)
- 3 concentric rings, `CFGradient.pulse` stroke
- Animation: scale 1.0 → 2.4, opacity 0.7 → 0, 2s ease-out
- Stagger: ring 2 delay 0.5s, ring 3 delay 1.0s
- Rings stop when toggle is off

### Animal card (grid item)
- Size: 80 × 90pt
- Background: `CFColor.surfaceCard` + `CFColor.borderSubtle` border
- Emoji: 36pt centered
- Label: `CFFont.caption()`, `CFColor.textSecondary`
- Selected: `CFGradient.brand` border (2pt), inner glow (`CFColor.gradientStart` at 0.3 opacity)

### Sensitivity control
- Segmented: Low / Medium / High
- Active segment: `CFGradient.brand` fill

### Banner ad container
- Height: 50pt, full width, bottom-anchored
- Background: `CFColor.adContainer`
- Visual separation from app content — not blended into gradient

---

## Accessibility
- Minimum contrast 4.5:1 on body text against `backgroundPrimary`
- Animal grid: `accessibilityLabel = "[animal name], [sound type]. [Selected/not selected]."`
- Listening toggle: `accessibilityLabel = "Clap detection [on/off]"`
- Support Dynamic Type on all text elements
- Reduce Motion: disable pulse ring animation, use static opacity instead

---

## Audit history

| Date | Rev | Summary |
|------|-----|---------|
| 2026-06-07 | v1 | Initial draft — kickoff artifact |
| 2026-06-09 | v2 | Swift token names added (CFColor, CFFont, CFRadius, CFSpacing, CFGradient) |
| 2026-06-09 | v3 | Signed off — ready for implementation |
