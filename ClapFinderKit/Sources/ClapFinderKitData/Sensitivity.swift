// MARK: - Sensitivity

/// Clap-detection sensitivity level.
///
/// The `threshold` value is expressed in **dBFS** (decibels relative to full scale).
/// A higher (less-negative) value means the mic must hear a louder sound before
/// a clap is registered. Lower (more-negative) values pick up quieter claps.
///
/// | Level  | Threshold | Best for                          |
/// |--------|-----------|-----------------------------------|
/// | low    | −30 dBFS  | Quiet rooms, close claps          |
/// | medium | −40 dBFS  | General use (default)             |
/// | high   | −50 dBFS  | Noisy environments, distant claps |
public enum Sensitivity: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high

    /// Detection threshold in dBFS. More-negative = more sensitive.
    /// (Legacy energy path; clap mode now uses the classifier — see
    /// `clapConfidenceThreshold`. Kept for reference / potential pre-gate.)
    public var threshold: Float {
        switch self {
        case .low:    return -30.0
        case .medium: return -40.0
        case .high:   return -50.0
        }
    }

    /// Minimum SoundAnalysis confidence for a clap-family classification to
    /// count as a clap event (SOUND_RECOGNITION_DESIGN.md §2). Lower = more
    /// forgiving (catches distant/soft claps). QA-calibrated defaults.
    public var clapConfidenceThreshold: Double {
        switch self {
        case .low:    return 0.75
        case .medium: return 0.55
        case .high:   return 0.40
        }
    }

    /// Human-readable label for display in the UI.
    public var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
}
