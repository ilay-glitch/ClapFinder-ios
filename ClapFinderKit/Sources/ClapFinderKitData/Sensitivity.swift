// MARK: - Sensitivity

/// Clap-detection sensitivity level.
///
/// Clap mode keys off **crest factor** (impulsiveness), not loudness, because
/// crest is distance-stable while loudness isn't.
///
/// | Level  | Min crest | Best for              |
/// |--------|-----------|-----------------------|
/// | low    | 3.5       | Sharp / close claps   |
/// | medium | 2.8       | General use (default) |
/// | high   | 2.2       | Far / soft claps      |
public enum Sensitivity: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high

    /// Minimum crest factor (peak ÷ RMS) for a buffer to count as a clap.
    /// This is the clap discriminator — and it's **distance-stable** (a real
    /// clap measures ~3.3+ near or far), unlike loudness which drops with
    /// distance. Lower = catches softer / farther claps. The detector also
    /// applies a fixed low dB floor only to reject silence.
    public var clapCrestThreshold: Float {
        switch self {
        case .low:    return 3.5   // sharp, clear claps only
        case .medium: return 2.8   // default — catches room-distance claps
        case .high:   return 2.2   // soft / far claps
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
