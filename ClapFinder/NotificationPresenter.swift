import ClapFinderKitMotion
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
/// `@unchecked Sendable`: stateless (only a static logger) — safe to share
/// across the arbitrary queues UNUserNotificationCenter calls back on.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    static let shared = NotificationPresenter()

    private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "Notifications"
    )

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Self.logger.info("Presenting in foreground: \(notification.request.identifier, privacy: .public)")
#if DEBUG
        // Path discriminator: a row here = this delivery took the FOREGROUND
        // (willPresent) path. Deliveries with no row took the normal path.
        let state = await MainActor.run { NotifDiag.appState() }
        NotifDiag.log("willPresent \(notification.request.identifier) appState=\(state)")
#endif
        return [.banner, .list, .sound]
    }
}
