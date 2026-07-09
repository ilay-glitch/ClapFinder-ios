import Foundation

#if canImport(UserNotifications) && os(iOS)
import UserNotifications
#endif

#if DEBUG

// MARK: - LED / delivery diagnostics (DEBUG only)

public extension TouchAlertCoordinator {

    /// LED isolation probe (2026-07-09 round 3): delivers on a locked phone
    /// with NO alarm running — separates "our notifications never trigger the
    /// accessibility LED" from "the LED is suppressed while the device is
    /// mid-alarm (audio blaring / screen awake)".
    func scheduleLEDTestNotification(id: String, delay: TimeInterval) {
#if canImport(UserNotifications) && os(iOS)
        let content = UNMutableNotificationContent()
        content.title = "LED test"
        content.body = "Diagnostics: did the flash blink for this?"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        UNUserNotificationCenter.current()
            .add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
                NotifDiag.log("add \(id) (+\(Int(delay))s) error=\(error?.localizedDescription ?? "nil")")
            }
#endif
    }

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
                    .filter { $0.hasPrefix("touchAlert.alarm") || $0.hasPrefix("notifdiag.test") }
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
