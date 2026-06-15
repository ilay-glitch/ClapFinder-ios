import Foundation

// MARK: - ClapListeningControl

/// Process-wide bridge so the clap-listening Live Activity's Stop button can
/// stop listening (parallels `TouchAlertControl`).
///
/// While listening the app process is alive (the AVAudioEngine mic session),
/// so `StopListeningIntent` — a `LiveActivityIntent` running in the app
/// process on iOS 17+ — calls `requestStop()`, which invokes the handler the
/// live `ResponseCoordinator` registered.
@MainActor
public enum ClapListeningControl {

    public private(set) static var stopHandler: (() -> Void)?

    public static func register(stop: @escaping () -> Void) {
        stopHandler = stop
    }

    public static func clear() {
        stopHandler = nil
    }

    /// Invoked by the Live Activity Stop button. No-op if not listening.
    public static func requestStop() {
        stopHandler?()
    }
}
