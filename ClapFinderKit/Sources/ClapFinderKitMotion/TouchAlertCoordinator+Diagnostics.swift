import Foundation

#if canImport(UserNotifications) && os(iOS)
import UserNotifications
#endif

#if DEBUG

// MARK: - LED / delivery diagnostics (DEBUG only)

public extension TouchAlertCoordinator {

#if canImport(UserNotifications) && os(iOS)
    /// Delivered snapshots at +2/+7/+12 s (0 s + both repeats), each taken
    /// before disarm can clear the list.
    func logDeliveredSnapshots(center: UNUserNotificationCenter) {
        Task { @MainActor in
            var elapsed = 0.0
            for checkpoint in [2.0, 7.0, 12.0] {
                try? await Task.sleep(for: .seconds(checkpoint - elapsed))
                elapsed = checkpoint
                let delivered = await center.deliveredNotifications()
                    .map(\.request.identifier)
                    .filter { $0.hasPrefix("touchAlert.alarm") }
                NotifDiag.log(
                    "delivered@\(Int(checkpoint))s=\(delivered.joined(separator: "|"))"
                    + " appState=\(NotifDiag.appState())"
                )
            }
        }
    }
#endif
}

#endif
