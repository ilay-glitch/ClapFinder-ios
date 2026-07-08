import AVFoundation
import Foundation
import OSLog

// MARK: - SilentKeepAlive

/// Playback-only background keep-alive for the touch alert (PIVOT.md §5, P2).
///
/// CoreMotion only delivers while the process executes and iOS has no motion
/// background mode. Pre-pivot this was a `ClapDetector` mic tap
/// (`.playAndRecord`) — which made the **microphone permission load-bearing**.
/// This replacement loops a silent buffer through an output-only engine on a
/// `.playback` session (`mixWithOthers`), keeping the process alive with **no
/// record path and no mic permission**. The audible alarm shares the same
/// session justification for `UIBackgroundModes: audio`.
///
/// Surface mirrors the old keep-alive (`isListening`, `start`, `stop`) so the
/// proven `TouchAlertCoordinator` logic — including the §4.2 watchdog that
/// stands down when `isListening` flips false — is unchanged in shape.
@Observable
@MainActor
public final class SilentKeepAlive {

    // MARK: Public state

    /// `true` while the silent engine is running. The touch-alert watchdog
    /// treats a false here (while armed) as "monitoring is not trustworthy".
    public private(set) var isListening = false

    // MARK: Private

    // Main-actor confined, like ClapDetector's engine.
    nonisolated(unsafe) private let engine = AVAudioEngine()
    nonisolated(unsafe) private let player = AVAudioPlayerNode()
    private var interruptionTask: Task<Void, Never>?
    private var configured = false

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "SilentKeepAlive"
    )

    public init() {}

    // MARK: API

    /// Starts the silent loop. Throws like the old keep-alive so the
    /// coordinator's error path is unchanged.
    public func start() throws {
#if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            throw ClapDetectorError.audioSessionConfigFailed(underlying: error)
        }
#endif
        do {
            if !configured {
                let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                engine.mainMixerNode.outputVolume = 0
                configured = true
            }
            try engine.start()
            scheduleSilence()
            player.play()
        } catch {
            throw ClapDetectorError.engineStartFailed(underlying: error)
        }
        startInterruptionObserver()
        isListening = true
        Self.logger.info("Silent keep-alive started (.playback, no mic)")
    }

    public func stop() {
        player.stop()
        engine.stop()
        interruptionTask?.cancel()
        interruptionTask = nil
        isListening = false
        Self.logger.info("Silent keep-alive stopped")
    }

    // MARK: Private

    /// One second of silence, scheduled on a loop — zero audible output, keeps
    /// the audio session (and therefore the process) alive in background.
    private func scheduleSilence() {
        guard let format = player.outputFormat(forBus: 0) as AVAudioFormat?,
              let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(format.sampleRate)) else { return }
        buffer.frameLength = buffer.frameCapacity   // zero-filled = silence
        player.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    /// Interruptions (calls, Siri, other apps taking the session): resume when
    /// the system says so; otherwise flip `isListening` so the coordinator's
    /// watchdog notifies + stands down (§4.2 — unchanged behaviour).
    private func startInterruptionObserver() {
#if os(iOS)
        interruptionTask?.cancel()
        interruptionTask = Task { @MainActor [weak self] in
            let notes = NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            )
            for await note in notes {
                guard !Task.isCancelled else { return }
                self?.handleInterruption(note)
            }
        }
#endif
    }

#if os(iOS)
    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        switch type {
        case .began:
            Self.logger.info("Keep-alive interrupted — pausing")
            engine.pause()
        case .ended:
            let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            if AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                    try engine.start()
                    player.play()
                    Self.logger.info("Keep-alive resumed after interruption")
                } catch {
                    Self.logger.error("Keep-alive resume failed: \(error) — standing down")
                    stop()   // isListening=false → watchdog notifies + disarms
                }
            } else {
                Self.logger.info("Interruption ended without shouldResume — standing down")
                stop()
            }
        @unknown default:
            break
        }
    }
#endif

    // MARK: Testing support

    /// ⚠️ TEST-ONLY. Sets `isListening` without touching the real engine.
    @_spi(Testing)
    public func setListeningForTesting(_ listening: Bool) {
        isListening = listening
    }
}
