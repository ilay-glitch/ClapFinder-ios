# Phase 1 Implementation Brief — ClapFinder

You are the coding agent for ClapFinder, a free iOS utility app.
The mechanic: clap twice → phone plays a loud animal sound + flashes the flashlight.
Target audience: families with children. Free + ads (ads are Phase 2).

**Read SKILL.md before writing any code.** It contains the module structure, key patterns, and
conventions. Do not deviate without surfacing the deviation first.

---

## Project parameters

| Parameter | Value |
|-----------|-------|
| Bundle ID | `com.appcentral.clapfinder` |
| iOS target | 17.0+ |
| Swift | 6.0, strict concurrency |
| UI | SwiftUI, Universal (iPhone + iPad) |
| Architecture | ClapFinderKit local SPM package, 5 modules |
| Reference | Boomr iOS (sibling repo) — same Kit pattern, same AudioEngine pattern |

---

## Phase 1 PRs — work in order

### PR-1: Repo scaffold (`phase1/pr-1-repo-scaffold`)
- ClapFinderKit SPM package with 5 module stubs
- ClapFinder/ app directory structure (no .xcodeproj — PM creates it in Xcode)
- `.swiftlint.yml`, `scripts/lint/all.sh`, `scripts/lint/no-hardcoded-hex.sh`, `scripts/lint/no-hardcoded-strings.sh`
- `SKILL.md`, `PROMPT_PHASE_1.md`, `CLAUDE.md`, `.gitignore`
- Initial commit to `main`, then branch and PR

### PR-2: Design tokens (`phase1/pr-2-design-tokens`)
- Implement `ClapFinderKitDesign` module per DESIGN.md
- Color tokens, typography scale, shape tokens as Swift enums/structs
- Hex literals ONLY in this module
- DESIGN.md v3 signoff required before code merges

### PR-3: Data layer (`phase1/pr-3-data-layer`)
- `Animal` struct: `id: String`, `name: String`, `emoji: String`, `soundFile: String`
- `catalog.json` with all 16 animals (see SKILL.md for full list)
- `Sensitivity` enum: `.low` / `.medium` / `.high` with `threshold: Float` computed property
- `CatalogStore` (`@Observable`): loads catalog.json, persists `selectedAnimalID` + `sensitivity` via UserDefaults
- Unit tests for CatalogStore loading and persistence

### PR-4: Clap detection engine (`phase1/pr-4-clap-detection`)
**Core technical risk — do not skip tests.**
- `ClapDetector` (`@Observable`, `nonisolated let engine = AVAudioEngine()`)
- Input tap → RMS → dBFS → threshold comparison (see SKILL.md for algorithm)
- 2 threshold crossings within 500ms → `onClapDetected` callback
- Debounce: 2s suppression after firing
- Unit tests: test 2-clap-in-500ms logic with mocked signal timing
- **If real-device testing shows detection is unreliable, surface and wait — do not adjust thresholds speculatively**

### PR-5: Response layer (`phase1/pr-5-response-layer`)
- `SoundPlayer`: loads animal .caf from bundle, plays at max volume via AVAudioSession
  - If real audio files are unavailable, use silent placeholder .caf — note this in cadence output
- `FlashlightController`: AVCaptureDevice torch, 3× pulse (150ms on / 100ms off)
- `ResponseCoordinator` (`@Observable`): listens for ClapDetector callback, fires both simultaneously
- Unit tests: mock SoundPlayer + FlashlightController, verify ResponseCoordinator triggers both

### PR-6: Home UI (`phase1/pr-6-home-ui`)
- Implement against `HOME_MOCKUP.html` (repo root)
- `HomeView`: pulsing ring animation, animal grid (4 cols), sensitivity segmented control, on/off toggle
- Animation: 3 concentric rings, gradient (violet→pink→orange), scale + opacity, 2s ease-out, staggered
- Animal grid: 16 cards, 4×4, selected state with gradient border
- Listening toggle: 72pt circle, gradient fill active
- All user-visible strings via Localizable.strings (no-hardcoded-strings lint rule enforced)
- No hex literals (no-hardcoded-hex lint rule enforced)

### PR-7: Background mode (`phase1/pr-7-background-mode`)
- `Info.plist`: `UIBackgroundModes = ["audio"]`
- `NSMicrophoneUsageDescription`: family-appropriate copy
- AVAudioSession configured at app launch (see SKILL.md for category + options)
- Real-device QA required before PR merges: screen off, 10+ min, 3 consecutive clap triggers

### PR-8: ATT prompt (`phase1/pr-8-att-prompt`)
- `ATTManager` (`@Observable`): requests tracking authorization ~2s after home screen appears
- Copy: "ClapFinder uses this to show you relevant ads. Your privacy is important to us."
- First-launch only — persist status, don't re-prompt

---

## At each PR, provide

1. What's implemented
2. Tests: what they cover and results
3. Spec deviations or open questions
4. Real-device QA results (if applicable)
5. Lint status: `bash scripts/lint/all.sh`

---

## Process rules (non-negotiable)

- **Pause and surface** when you find under-specced areas or doc/code divergence.
- **Doc commits first** on any PR touching both a doc and code.
- **No Phase 2 work** (ads, analytics, Adjust) in Phase 1 PRs.
- **Cadence notes** at PR open: deviations, blockers, open questions.
