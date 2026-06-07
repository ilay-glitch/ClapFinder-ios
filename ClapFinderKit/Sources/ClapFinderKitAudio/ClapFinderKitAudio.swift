/// ClapFinderKitAudio
///
/// Responsibilities:
/// - ClapDetector: AVAudioEngine input tap, RMS amplitude, 2-clap-in-500ms detection
/// - SoundPlayer: animal sound playback at max volume via AVAudioSession
/// - FlashlightController: AVCaptureDevice torch, 3x pulse
/// - ResponseCoordinator: orchestrates ClapDetector → SoundPlayer + FlashlightController
public enum ClapFinderKitAudio {}
