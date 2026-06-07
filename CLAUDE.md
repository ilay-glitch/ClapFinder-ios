# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project

ClapFinder is a free iOS utility app: clap twice → your phone plays a loud animal sound + flashes the flashlight. Target: families with children. Free + ads (ad network TBD, Phase 2). All Ages App Store category.

**Identifiers**

| Item | Value |
|------|-------|
| Bundle ID | `com.appcentral.clapfinder` |

## Commands

```bash
# Lint (run before every PR; CI runs the same)
bash scripts/lint/all.sh

# Build ClapFinderKit
cd ClapFinderKit && swift build -v

# Test ClapFinderKit
cd ClapFinderKit && swift test -v

# Build Boomr app (after Xcode project exists — created manually in PR-1)
xcodebuild build \
  -project ClapFinder.xcodeproj \
  -scheme ClapFinder \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

## Architecture

**`ClapFinderKit/`** — local Swift Package (Swift 6, iOS 17+). Five modules:

| Module | Responsibility |
|--------|----------------|
| `ClapFinderKitDesign` | Design tokens — color, type, shape. Only place hex literals allowed. |
| `ClapFinderKitAudio` | Clap detection (AVAudioEngine), sound playback, flashlight, response coordination. |
| `ClapFinderKitData` | Animal model, catalog.json (16 animals), CatalogStore, Sensitivity enum. |
| `ClapFinderKitAds` | Ad integration stub (Phase 2). |
| `ClapFinderKitLocalization` | L10n helpers (stub). |

**`ClapFinder/`** — Xcode app target. Imports ClapFinderKit as local SPM dependency.

## Conventions

**Branching & commits**
- Branch naming: `phase{N}/pr-{M}-{kebab-case-description}`
- Commit prefixes: `docs:`, `code:`, `tests:`, `chore:`, `fix:`
- Doc commits land BEFORE code commits on same branch.

**Process**
- Pause and surface under-specced areas. Never expand scope silently.
- Phase boundaries are real. Phase 2 (ads, analytics) stays out of Phase 1 PRs.

**Canonical docs**
- `SKILL.md` — architecture conventions (load at every session start)
- `PROMPT_PHASE_1.md` — Phase 1 brief
- `PLAN.md` — phase plan
- `DESIGN.md` — visual/UX tokens
- `HOME_MOCKUP.html`, `SETTINGS_MOCKUP.html` — visual targets

## Lint Rules

`scripts/lint/all.sh` runs SwiftLint + two custom bash rules:

- **no-hardcoded-hex**: hex color literals forbidden outside `ClapFinderKitDesign`.
  Suppress: `// allow-hardcoded-hex until: pr-N`
- **no-hardcoded-strings**: user-visible string literals in SwiftUI components must use Localizable.strings.
  Suppress: `// allow-hardcoded-string until: pr-N`

## Setup Notes

- `ClapFinder/` app target Xcode project (.xcodeproj) is created manually via Xcode →
  File → New → Project → iOS App, Bundle ID `com.appcentral.clapfinder`, add ClapFinderKit as local SPM dep.
- Each `ClapFinderKit/Sources/{Module}/` needs at least one .swift file for SPM to resolve.
- Sound files (.caf) are added to the Xcode bundle in PR-5. Use silent placeholders during development.
