// MARK: - FlashlightController

#if os(iOS)
import AVFoundation
import Observation
import OSLog

/// Pulses the rear-facing torch 3× on double-clap detection.
///
/// Pulse pattern: 150 ms on → 100 ms off (×3), total ≈ 750 ms.
///
/// The controller is a no-op when:
/// - The device has no torch (iPod Touch, simulator).
/// - A pulse is already in progress (`isPulsing == true`).
@Observable
@MainActor
public final class FlashlightController {

    // MARK: Constants

    /// Number of on/off cycles per trigger.
    public let pulseCount = 3
    /// Duration the torch stays **on** per cycle (seconds).
    public let onDuration: Double = 0.150
    /// Duration the torch stays **off** between pulses (seconds).
    public let offDuration: Double = 0.100

    // MARK: Public state

    /// `true` while a pulse sequence is running.
    public private(set) var isPulsing = false

    // MARK: Logging

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "FlashlightController"
    )

    // MARK: Init

    public init() {}

    // MARK: Public API

    /// Starts a 3× torch pulse sequence.
    ///
    /// Returns immediately; the pulse runs as a background Task on the main actor.
    /// Call is ignored if `isPulsing` is already `true`.
    public func pulse() {
        guard !isPulsing else { return }

        guard
            let device = AVCaptureDevice.default(for: .video),
            device.hasTorch
        else {
            Self.logger.warning("Torch unavailable — skipping pulse")
            return
        }

        isPulsing = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            await self.runPulse(device: device)
            self.isPulsing = false
        }
    }

    // MARK: Continuous pulsing (touch-alert alarm)

    private var continuousTask: Task<Void, Never>?

    /// Pulses the torch continuously until `stopContinuousPulse()`.
    /// Idempotent while running; no-op without a torch.
    public func startContinuousPulse() {
        guard continuousTask == nil else { return }

        guard
            let device = AVCaptureDevice.default(for: .video),
            device.hasTorch
        else {
            Self.logger.warning("Torch unavailable — skipping continuous pulse")
            return
        }

        isPulsing = true
        continuousTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.runPulse(device: device)
                try? await Task.sleep(for: .seconds(self.offDuration))
            }
        }
    }

    /// Stops continuous pulsing and forces the torch off.
    public func stopContinuousPulse() {
        continuousTask?.cancel()
        continuousTask = nil
        if let device = AVCaptureDevice.default(for: .video), device.hasTorch {
            setTorch(device: device, isOn: false)
        }
        isPulsing = false
    }

    // MARK: Private

    private func runPulse(device: AVCaptureDevice) async {
        for index in 0..<pulseCount {
            setTorch(device: device, isOn: true)
            try? await Task.sleep(for: .seconds(onDuration))
            setTorch(device: device, isOn: false)
            if index < pulseCount - 1 {
                try? await Task.sleep(for: .seconds(offDuration))
            }
        }
        Self.logger.debug("Torch pulse complete (\(self.pulseCount)×)")
    }

    private func setTorch(device: AVCaptureDevice, isOn: Bool) {
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
        } catch {
            Self.logger.error("Torch lockForConfiguration failed: \(error)")
        }
    }
}

#else

// MARK: - macOS stub (package builds cleanly on CLI / Simulator without camera)

import Observation

/// No-op stub on platforms without a torch.
@Observable
@MainActor
public final class FlashlightController {
    public let pulseCount = 3
    public let onDuration: Double = 0.150
    public let offDuration: Double = 0.100
    public private(set) var isPulsing = false
    public init() {}
    public func pulse() { /* no torch on macOS */ }
    public func startContinuousPulse() { isPulsing = true }
    public func stopContinuousPulse() { isPulsing = false }
}

#endif
