import Foundation
import OSLog

// MARK: - AnalyticsEvent

/// A single analytics event. Names and params are defined in EVENTS.md
/// (doc-leads-code) and written to be Firebase-compatible: snake_case,
/// name ≤ 40 chars, ≤ 25 params.
public struct AnalyticsEvent: Equatable, Sendable {
    public let name: String
    public let params: [String: AnalyticsValue]

    public init(name: String, params: [String: AnalyticsValue] = [:]) {
        self.name = name
        self.params = params
    }
}

/// Param value — restricted to the types every downstream transport
/// (OSLog now, Firebase later) can represent losslessly.
public enum AnalyticsValue: Equatable, Sendable, CustomStringConvertible {
    case string(String)
    case int(Int)
    case bool(Bool)

    public var description: String {
        switch self {
        case .string(let value):
            return value
        case .int(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        }
    }
}

// MARK: - AnalyticsClient

/// Transport seam for analytics. The Firebase adapter conforms to this
/// in the analytics PR; until then `OSLogAnalyticsClient` is the
/// production default and tests inject recorders.
public protocol AnalyticsClient: Sendable {
    func log(_ event: AnalyticsEvent)
}

/// Default client — structured OSLog lines, visible in Console.app
/// under subsystem `com.appcentral.clapfinder`, category `Analytics`.
public struct OSLogAnalyticsClient: AnalyticsClient {

    private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "Analytics"
    )

    public init() {}

    public func log(_ event: AnalyticsEvent) {
        let params = event.params
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        Self.logger.info("event=\(event.name, privacy: .public) \(params, privacy: .public)")
    }
}

// MARK: - Splash events (EVENTS.md — Splash / App Open Ad)

/// Typed constructors for the PR-10 event schema. Keeping construction
/// in one place means a schema change is a one-file diff + EVENTS.md.
public enum SplashAnalytics {

    public static func splashShown(coldLaunch: Bool, firstLaunch: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "splash_shown", params: [
            "cold_launch": .bool(coldLaunch),
            "first_launch": .bool(firstLaunch)
        ])
    }

    public static func adRequested(attAuthorized: Bool) -> AnalyticsEvent {
        AnalyticsEvent(name: "app_open_ad_requested", params: [
            "att_authorized": .bool(attAuthorized)
        ])
    }

    public static func adShown() -> AnalyticsEvent {
        AnalyticsEvent(name: "app_open_ad_shown")
    }

    public static func adFailed(errorReason: String) -> AnalyticsEvent {
        AnalyticsEvent(name: "app_open_ad_failed", params: [
            "error_reason": .string(errorReason)
        ])
    }

    public static func adTimeout(elapsedMs: Int) -> AnalyticsEvent {
        AnalyticsEvent(name: "app_open_ad_timeout", params: [
            "elapsed_ms": .int(elapsedMs)
        ])
    }

    public static func splashCompleted(
        durationMs: Int,
        adShown: Bool,
        skipReason: AdSkipReason
    ) -> AnalyticsEvent {
        AnalyticsEvent(name: "splash_completed", params: [
            "duration_ms": .int(durationMs),
            "ad_shown": .bool(adShown),
            "ad_skip_reason": .string(skipReason.rawValue)
        ])
    }
}
