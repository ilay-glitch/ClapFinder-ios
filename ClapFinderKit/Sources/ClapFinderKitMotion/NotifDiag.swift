import Foundation

#if canImport(UIKit)
import UIKit
#endif

// MARK: - NotifDiag (DEBUG-only)

/// Notification delivery diagnostics → `Documents/notifdiag.csv` (the pullable
/// file pattern; OSLog is unreadable headless — device streaming needs root).
/// Answers, per C6 run: were the alarm notifications scheduled (add errors?),
/// under what authorization, were they delivered, what was the app state at
/// alarm-from-locked, and which presentation path each delivery took
/// (`willPresent` foreground path vs normal). PM hypothesis under test: the
/// accessibility LED may fire only on the NORMAL delivery path.
public enum NotifDiag {

    public static func log(_ line: String) {
#if DEBUG
        guard let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("notifdiag.csv") else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
#endif
    }

    /// Current UIApplication state — the "foreground-but-locked?" question.
    public static func appState() -> String {
#if canImport(UIKit) && os(iOS)
        if Thread.isMainThread {
            switch UIApplication.shared.applicationState {
            case .active: return "active"
            case .inactive: return "inactive"
            case .background: return "background"
            @unknown default: return "unknown"
            }
        }
        return "offMain"
#else
        return "n/a"
#endif
    }
}
