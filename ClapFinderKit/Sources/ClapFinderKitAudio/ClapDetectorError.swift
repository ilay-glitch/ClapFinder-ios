// MARK: - ClapDetectorError

/// Errors thrown by `ClapDetector.start()`.
public enum ClapDetectorError: Error, Sendable {
    /// The microphone permission has not been granted.
    case microphonePermissionDenied
    /// AVAudioEngine failed to start; see `underlying` for the original error.
    case engineStartFailed(underlying: any Error)
    /// AVAudioSession configuration failed; see `underlying` for the original error.
    case audioSessionConfigFailed(underlying: any Error)
}
