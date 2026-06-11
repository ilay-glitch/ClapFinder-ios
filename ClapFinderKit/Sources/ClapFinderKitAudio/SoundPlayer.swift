import AVFoundation
import ClapFinderKitData
import Observation
import OSLog

// MARK: - SoundPlayer

/// Plays a single animal sound file from a given bundle at maximum volume.
///
/// Sound files are stored in the **app** bundle (`ClapFinder/Resources/Audio/`),
/// not the ClapFinderKit framework bundle. The caller passes the bundle in
/// `play(animal:in:)` — defaults to `Bundle.main` in production.
///
/// ```swift
/// soundPlayer.play(animal: selectedAnimal)   // uses Bundle.main
/// ```
@Observable
@MainActor
public final class SoundPlayer {

    // MARK: Public state

    /// `true` while a sound is actively playing.
    public private(set) var isPlaying = false

    // MARK: Private

    private var player: AVAudioPlayer?

    // MARK: Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "SoundPlayer"
    )

    // MARK: Init

    public init() {}

    // MARK: Public API

    /// Plays the sound file for `animal`.
    ///
    /// - Parameters:
    ///   - animal: The animal whose sound to play.
    ///   - bundle: Bundle containing the CAF audio resource (default: `Bundle.main`).
    ///   - loop: When `true`, the sound repeats until `stop()` is called
    ///     (touch-alert alarm). Default `false` plays once.
    public func play(animal: Animal, in bundle: Bundle = .main, loop: Bool = false) {
        stop()  // cancel any in-progress sound

        guard let url = bundle.url(forResource: animal.soundFile, withExtension: nil) else {
            Self.logger.error("Sound file not found: \(animal.soundFile) in \(bundle.bundlePath)")
            return
        }

        do {
            let audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer.volume = 1.0
            audioPlayer.numberOfLoops = loop ? -1 : 0
            audioPlayer.prepareToPlay()
            audioPlayer.play()
            player = audioPlayer
            isPlaying = true
            let trackDuration = audioPlayer.duration
            Self.logger.debug(
                "Playing \(animal.soundFile) (duration \(trackDuration, format: .fixed(precision: 2))s, loop \(loop))"
            )

            // Flip isPlaying back to false after the track finishes (one-shot only —
            // a looping player keeps isPlaying true until stop()).
            if !loop {
                let duration = trackDuration
                Task { @MainActor [weak self, weak audioPlayer] in
                    try? await Task.sleep(for: .seconds(max(duration, 0.05)))
                    // Guard against the player being replaced mid-flight
                    if self?.player === audioPlayer { self?.isPlaying = false }
                }
            }
        } catch {
            Self.logger.error("AVAudioPlayer init failed: \(error)")
        }
    }

    /// Stops playback immediately.
    public func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}
