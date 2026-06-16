import ClapFinderKitData
import Foundation
import Observation
import OSLog

// MARK: - ClapCalibrationController

/// Runs a short clap-calibration capture and derives a personalised crest
/// threshold (SOUND_RECOGNITION_DESIGN.md §5). Owns its own `ClapDetector`
/// in capture mode; the caller persists the resulting threshold.
@Observable
@MainActor
public final class ClapCalibrationController {

    public enum State: Equatable, Sendable {
        case idle
        case capturing
        /// Calibration succeeded with this personalised crest threshold.
        case success(Float)
        /// Too few claps heard — the user should retry.
        case failed
    }

    public private(set) var state: State = .idle

    /// How long to listen for calibration claps.
    public let captureDuration: TimeInterval = 4.0

    private let detector: ClapDetector
    private var samples: [Float] = []
    private var captureTask: Task<Void, Never>?

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ClapCalibration"
    )

    public init(detector: ClapDetector = ClapDetector()) {
        self.detector = detector
    }

    /// Begins capturing. The user should double-clap a couple of times during
    /// the window. Resolves to `.success`/`.failed` after `captureDuration`.
    public func start() {
        guard state != .capturing else { return }
        samples = []
        state = .capturing
        do {
            try detector.startCalibration { [weak self] crest in
                self?.samples.append(crest)
            }
        } catch {
            Self.logger.error("Calibration start failed: \(error.localizedDescription)")
            state = .failed
            return
        }
        captureTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.captureDuration))
            guard !Task.isCancelled else { return }
            self.finish()
        }
    }

    /// Aborts an in-progress capture and returns to idle.
    public func cancel() {
        captureTask?.cancel()
        captureTask = nil
        detector.stopCalibration()
        state = .idle
    }

    /// Resets after the caller has consumed a success/failure result.
    public func reset() {
        state = .idle
    }

    private func finish() {
        captureTask = nil
        detector.stopCalibration()
        if let threshold = ClapCalibration.threshold(fromCrests: samples) {
            Self.logger.info("Calibrated crest threshold: \(threshold) from \(self.samples.count) samples")
            state = .success(threshold)
        } else {
            Self.logger.info("Calibration failed — \(self.samples.count) samples, too few claps")
            state = .failed
        }
    }
}
