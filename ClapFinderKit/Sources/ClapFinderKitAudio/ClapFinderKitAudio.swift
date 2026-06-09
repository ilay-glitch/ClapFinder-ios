/// ClapFinderKitAudio
///
/// Responsibilities:
/// - `ClapDetector` — AVAudioEngine input tap, RMS → dBFS, 2-clap-in-500ms detection
/// - `ClapDetectorError` — typed errors for start() failures
/// - `SoundPlayer` — animal sound playback at max volume (PR-5)
/// - `FlashlightController` — AVCaptureDevice torch, 3× pulse (PR-5)
/// - `ResponseCoordinator` — orchestrates detector → sound + flashlight (PR-5)
public enum ClapFinderKitAudio {}
