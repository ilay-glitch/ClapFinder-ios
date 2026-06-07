# ClapFinder — Coding Agent Skill File
Load this file at the start of every session before writing any code.

---

## Project identity

- **App:** ClapFinder — iOS utility, "clap twice to find your phone"
- **Bundle ID:** `com.appcentral.clapfinder`
- **iOS target:** 17.0+ | Swift 6 strict concurrency | SwiftUI | Universal (iPhone + iPad)
- **Reference codebase:** Boomr iOS (sibling repo, same company, same Kit pattern)

---

## Module map

```
ClapFinderKit/                    ← local SPM package
  Sources/
    ClapFinderKitDesign/          ← color tokens, type, shape. ONLY place hex literals allowed.
    ClapFinderKitAudio/           ← AVAudioEngine, ClapDetector, SoundPlayer,
                                     FlashlightController, ResponseCoordinator
    ClapFinderKitData/            ← Animal model, catalog.json, CatalogStore, Sensitivity enum
    ClapFinderKitAds/             ← Ad integration stub (Phase 2)
    ClapFinderKitLocalization/    ← L10n helpers (stub)
ClapFinder/                       ← Xcode app target. Imports ClapFinderKit as local SPM dep.
```

**Module dependency rules (no circular deps):**
- `ClapFinderKitAudio` → `ClapFinderKitDesign`, `ClapFinderKitData`
- `ClapFinderKitData` → `ClapFinderKitDesign`
- `ClapFinderKitAds` → `ClapFinderKitData`
- `ClapFinderKitLocalization` → (none)

---

## Key patterns

### Observable + nonisolated (mirrors Boomr AudioEngine)
```swift
@Observable
final class ClapDetector {
    nonisolated let engine = AVAudioEngine()
    var isListening = false
}
```
Use `nonisolated let` for AVFoundation objects — `AVAudioEngine`, `AVAudioPlayerNode`, `AVCaptureDevice`
are not Sendable. `nonisolated let` avoids data-race warnings under Swift 6 strict concurrency.

### Clap detection algorithm
1. Install input tap: `engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format:) { buffer, time in ... }`
2. Calculate RMS from `buffer.floatChannelData![0]` over `buffer.frameLength` samples
3. Convert: `dBFS = rms > 0 ? 20 * log10(rms) : -160`
4. Compare dBFS to `Sensitivity.threshold`
5. Track crossing timestamps (ring buffer, max 2 entries)
6. Two crossings within 500ms → fire response, reset, suppress 2s

### Sensitivity → dBFS thresholds
```swift
enum Sensitivity: String, CaseIterable, Codable {
    case low, medium, high
    var threshold: Float {
        switch self {
        case .low:    return -30   // louder clap required
        case .medium: return -40   // default
        case .high:   return -50   // detects quieter claps
        }
    }
}
```

### AVAudioSession config (call once at app launch)
```swift
try AVAudioSession.sharedInstance().setCategory(
    .playAndRecord,
    mode: .default,
    options: [.mixWithOthers, .allowBluetooth]
)
try AVAudioSession.sharedInstance().setActive(true)
```

### Silent-mode sound playback
Category `.playAndRecord` with active session plays audio even when ringer switch is off.
Verify on real device — simulator does not test this.

### Flashlight pulse (3×)
```swift
func pulseFlashlight(times: Int = 3) {
    guard let device = AVCaptureDevice.default(for: .video),
          device.hasTorch else { return }
    Task {
        for _ in 0..<times {
            try? device.lockForConfiguration()
            device.torchMode = .on
            device.unlockForConfiguration()
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms on
            try? device.lockForConfiguration()
            device.torchMode = .off
            device.unlockForConfiguration()
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms off
        }
    }
}
```

---

## Animal catalog (16 animals)

catalog.json lives in `ClapFinderKit/Sources/ClapFinderKitData/Resources/catalog.json`

| ID | Name | Emoji | Sound file |
|----|------|-------|------------|
| dog | Dog | 🐕 | dog_bark.caf |
| cat | Cat | 🐈 | cat_meow.caf |
| cow | Cow | 🐮 | cow_moo.caf |
| frog | Frog | 🐸 | frog_ribbit.caf |
| duck | Duck | 🦆 | duck_quack.caf |
| pig | Pig | 🐖 | pig_oink.caf |
| rooster | Rooster | 🐔 | rooster_crow.caf |
| sheep | Sheep | 🐑 | sheep_baa.caf |
| lion | Lion | 🦁 | lion_roar.caf |
| elephant | Elephant | 🐘 | elephant_trumpet.caf |
| monkey | Monkey | 🐒 | monkey_chatter.caf |
| fox | Fox | 🦊 | fox_yip.caf |
| wolf | Wolf | 🐺 | wolf_howl.caf |
| parrot | Parrot | 🦜 | parrot_hello.caf |
| dolphin | Dolphin | 🐬 | dolphin_click.caf |
| bee | Bee | 🐝 | bee_buzz.caf |

Sound files are added to the Xcode app bundle in PR-5. Use silent placeholder .caf files
if real audio isn't available yet — note this in cadence output.

---

## Lint rules

Enforced by `scripts/lint/all.sh` (SwiftLint + two custom bash rules):

- **no-hardcoded-hex**: hex literals forbidden outside `ClapFinderKitDesign`
  Suppress: `// allow-hardcoded-hex until: pr-N`
- **no-hardcoded-strings**: user-visible strings in SwiftUI components must use Localizable.strings
  Suppress: `// allow-hardcoded-string until: pr-N`
- Excluded from both: `Tests/`, `Preview`, `Debug/`

---

## Build + test commands

```bash
# Lint (run before every PR open)
bash scripts/lint/all.sh

# Build ClapFinderKit
cd ClapFinderKit && swift build -v

# Test ClapFinderKit
cd ClapFinderKit && swift test -v

# Build app (after Xcode project exists)
xcodebuild build \
  -project ClapFinder.xcodeproj \
  -scheme ClapFinder \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -quiet
```

---

## Branching convention

`phase{N}/pr-{M}-{kebab-case-description}`

Examples: `phase1/pr-4-clap-detection`, `phase1/pr-6-home-ui`

## Commit prefixes

`docs:` / `code:` / `tests:` / `chore:` / `fix:`

Doc commits always land **before** code commits on the same branch.

---

## Process rules

- **Pause and surface** on under-specced areas or doc/code divergence. Never expand scope silently.
- **Cadence notes** at PR open: spec deviations, open questions, real-device QA blockers.
- **Phase boundaries are real.** Phase 2 (ads, analytics, Adjust) stays out of Phase 1 PRs.
