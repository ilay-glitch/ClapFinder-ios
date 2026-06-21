import AVFoundation

// MARK: - ClapDetector spectral route eligibility
//
// Split out of ClapDetector.swift to keep it under the file-length cap. The
// stage-2 spectral veto (SOUND_RECOGNITION_DESIGN.md v3) runs only on the
// built-in mic; on Bluetooth / other routes HF roll-off would veto real claps,
// so we fall back to crest-only (§11 known limitation).

extension ClapDetector {

    /// Re-evaluates whether the current input route allows the spectral veto.
    /// Called at `start` and on every route change.
    func updateSpectralRouteEligibility() {
#if os(iOS)
        let inputs = AVAudioSession.sharedInstance().currentRoute.inputs
        routeAllowsSpectral = inputs.contains { $0.portType == .builtInMic }
#endif
    }
}
