import OSLog
import UserNotifications

// MARK: - NotificationPresenter

/// Foreground-presentation delegate (LED-blink bug, PM diagnosis 2026-07-09).
///
/// Without a `UNUserNotificationCenterDelegate` implementing `willPresent`,
/// iOS suppresses notifications delivered while the app is foreground — so the
/// alarm notification never "presented" and the system's LED Flash for Alerts
/// never fired. Presenting with `.banner/.list/.sound` restores delivery in
/// every app state; the LED blink rides the presentation.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationPresenter()

    private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "Notifications"
    )

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.logger.info("Presenting notification in foreground: \(notification.request.identifier, privacy: .public)")
        return [.banner, .list, .sound]
    }
}
