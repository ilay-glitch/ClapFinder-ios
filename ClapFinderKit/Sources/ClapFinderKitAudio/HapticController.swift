// MARK: - HapticController

#if os(iOS)
import AudioToolbox
import Observation
import OSLog
import UIKit

/// Continuous device vibration for the touch-alert alarm
/// (TOUCH_ALERT_DESIGN.md §3 — alarm response).
///
/// Uses the full-device vibration motor (`kSystemSoundID_Vibrate`) on a
/// repeating loop so it reads like a ringing phone, not a subtle taptic
/// tick — the right feel for an anti-theft alarm. Runs until stopped.
@Observable
@MainActor
public final class HapticController {

    /// `true` while the repeating vibration loop is running.
    public private(set) var isVibrating = false

    /// Gap between vibration pulses (the system buzz itself is ~0.4–1 s).
    public let pulseInterval: Double = 1.2

    private var loopTask: Task<Void, Never>?

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "HapticController"
    )

    public init() {}

    /// Starts the repeating vibration. Idempotent while running.
    public func startContinuous() {
        guard loopTask == nil else { return }
        isVibrating = true
        Self.logger.info("Continuous vibration started")
        loopTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                guard let self else { return }
                try? await Task.sleep(for: .seconds(self.pulseInterval))
            }
        }
    }

    /// Stops the vibration loop. Always wins, safe to call repeatedly.
    public func stop() {
        loopTask?.cancel()
        loopTask = nil
        isVibrating = false
    }
}

#else

// MARK: - macOS stub (no vibration motor)

import Observation

@Observable
@MainActor
public final class HapticController {
    public private(set) var isVibrating = false
    public let pulseInterval: Double = 1.2
    public init() {}
    public func startContinuous() { isVibrating = true }
    public func stop() { isVibrating = false }
}

#endif
