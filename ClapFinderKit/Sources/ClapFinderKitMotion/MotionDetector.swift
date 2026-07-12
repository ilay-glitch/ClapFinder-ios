import Foundation
import Observation
import OSLog

#if os(iOS)
import CoreMotion

// MARK: - MotionDetector

/// Thin `CMMotionManager` wrapper — mirrors how `ClapDetector` isolates
/// AVAudioEngine (TOUCH_ALERT_DESIGN.md §6).
///
/// Polls device motion at 10 Hz (§5 battery justification) and forwards
/// the gravity-removed user-acceleration magnitude to `onSample`.
/// All decisions live in `MotionAlertLogic`; this type only samples.
@Observable
@MainActor
public final class MotionDetector {

    // MARK: Public state

    public private(set) var isMonitoring = false

    /// Called on the main actor with (magnitude in g, timestamp).
    public var onSample: (@MainActor (Double, Date) -> Void)?

    // MARK: Private

    /// 10 Hz — a pickup spans 200–500 ms, so this samples it 2–5×.
    private let updateInterval: TimeInterval = 0.1

    // CMMotionManager is not Sendable; all access happens on the main actor.
    nonisolated(unsafe) private let manager = CMMotionManager()

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "MotionDetector"
    )

    // MARK: Init

    public init() {}

    // MARK: Public API

    /// Starts 10 Hz device-motion updates. No-op if already monitoring
    /// or the device has no motion hardware (returns `false`).
    @discardableResult
    public func start() -> Bool {
        guard !isMonitoring else { return true }
        guard manager.isDeviceMotionAvailable else {
            Self.logger.warning("Device motion unavailable — cannot monitor")
            return false
        }

        manager.deviceMotionUpdateInterval = updateInterval
#if DEBUG
        startDiagFile()
        let diagStart = Date()
#endif
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            if let error {
                Self.logger.error("Device motion error: \(error.localizedDescription)")
                return
            }
            guard let motion else { return }
            let accel = motion.userAcceleration
            let magnitude = (accel.x * accel.x + accel.y * accel.y + accel.z * accel.z).squareRoot()
#if DEBUG
            // Motion diagnostics (PM sessions: table-vibration vs real pickup).
            // Gravity vector = tilt signal; rotationRate = handling signal —
            // the candidate discriminators against raw-magnitude spikes.
            let grav = motion.gravity
            let rot = motion.rotationRate
            let rotMag = (rot.x * rot.x + rot.y * rot.y + rot.z * rot.z).squareRoot()
            let line = String(
                format: "%.2f,%.4f,%.3f,%.3f,%.3f,%.3f",
                Date().timeIntervalSince(diagStart), magnitude,
                grav.x, grav.y, grav.z, rotMag
            )
            Task { @MainActor [weak self] in self?.appendDiag(line) }
#endif
            Task { @MainActor [weak self] in
                self?.onSample?(magnitude, Date())
            }
        }

        isMonitoring = true
        Self.logger.info("Motion monitoring started (10 Hz)")
        return true
    }

#if DEBUG
    // MARK: Motion diagnostics (DEBUG only — Documents/motiondiag.csv)

    /// Appends per listen-session (repeated header = session delimiter), same
    /// pull path as clapdiag.csv: devicectl copy from the app container.
    private var diagURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("motiondiag.csv")
    }

    private func startDiagFile() {
        guard let url = diagURL else { return }
        let header = Data("t,uaMag,gravX,gravY,gravZ,rotMag\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: header)
        } else {
            try? header.write(to: url)
        }
    }

    private func appendDiag(_ line: String) {
        guard let url = diagURL, let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data((line + "\n").utf8))
    }
#endif

    /// Stops device-motion updates.
    public func stop() {
        guard isMonitoring else { return }
        manager.stopDeviceMotionUpdates()
        isMonitoring = false
        Self.logger.info("Motion monitoring stopped")
    }
}

#else

// MARK: - macOS stub (CLI builds + coordinator tests)

/// No-op detector for platforms without CoreMotion. `simulateSample`
/// lets coordinator tests drive the pipeline without hardware.
@Observable
@MainActor
public final class MotionDetector {

    public private(set) var isMonitoring = false
    public var onSample: (@MainActor (Double, Date) -> Void)?

    public init() {}

    @discardableResult
    public func start() -> Bool {
        isMonitoring = true
        return true
    }

    public func stop() {
        isMonitoring = false
    }

    /// Test hook — feeds a fake sample through `onSample`.
    public func simulateSample(magnitude: Double, at date: Date) {
        guard isMonitoring else { return }
        onSample?(magnitude, date)
    }
}

#endif
