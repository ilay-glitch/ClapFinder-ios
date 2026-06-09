/// ClapFinderKitAudio
///
/// Responsibilities:
/// - `ClapDetector` — AVAudioEngine input tap, RMS → dBFS, 2-clap-in-500ms detection
/// - `ClapDetectorError` — typed errors for start() failures
/// - `SoundPlayer` — animal sound playback at max volume via AVAudioPlayer
/// - `FlashlightController` — AVCaptureDevice torch, 3× pulse (150ms on / 100ms off)
/// - `ResponseCoordinator` — orchestrates ClapDetector → SoundPlayer + FlashlightController
public enum ClapFinderKitAudio {}
