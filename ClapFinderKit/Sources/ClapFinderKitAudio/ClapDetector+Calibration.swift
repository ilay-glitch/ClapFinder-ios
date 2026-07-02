import Foundation

// MARK: - ClapDetector calibration capture
//
// Split out of ClapDetector.swift (file-length cap). Same behaviour,
// byte-for-byte: capture mode forwards each above-floor buffer's crest to the
// handler instead of running detection (used by ClapCalibrationController).

extension ClapDetector {

    /// Forwards each above-floor buffer's crest to `onCrest` (no detection) to
    /// learn the user's clap. Call `stopCalibration()` when done.
    public func startCalibration(onCrest: @escaping @MainActor (Float) -> Void) throws {
        guard !isListening && calibrationHandler == nil else { return }
        calibrationHandler = onCrest
        do {
            try activateEngine()
        } catch {
            calibrationHandler = nil
            throw error
        }
        Self.logger.info("Calibration capture started")
    }

    public func stopCalibration() {
        guard calibrationHandler != nil else { return }
        calibrationHandler = nil
        tearDown()
        Self.logger.info("Calibration capture stopped")
    }
}
