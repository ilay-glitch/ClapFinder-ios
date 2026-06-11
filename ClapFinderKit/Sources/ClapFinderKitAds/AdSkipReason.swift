// MARK: - AdSkipReason

/// Why an App Open Ad was (or wasn't) skipped during the splash cycle.
///
/// Emitted as the `ad_skip_reason` param on `splash_completed`
/// (EVENTS.md). Distinguishes fill problems (`loadFailed`, `timeout`)
/// from caps working as designed (`firstLaunch`, `frequencyCap`,
/// `sessionCap`).
public enum AdSkipReason: String, Equatable, Sendable {
    /// Ad was shown — nothing skipped.
    case none
    /// First-ever launch; no request made (policy rule 2).
    case firstLaunch = "first_launch"
    /// Less than the minimum interval since the last app open ad (rule 4).
    case frequencyCap = "frequency_cap"
    /// An app open ad was already shown this session (rule 3).
    case sessionCap = "session_cap"
    /// Request was made; the SDK returned an error.
    case loadFailed = "load_failed"
    /// Request was made; the ad did not load within the splash ceiling.
    case timeout
}
