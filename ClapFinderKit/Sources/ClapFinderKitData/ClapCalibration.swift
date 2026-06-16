import Foundation

// MARK: - ClapCalibration

/// Pure logic for personalised clap calibration (SOUND_RECOGNITION_DESIGN.md).
///
/// The user double-claps during a short capture window; the app records the
/// crest factor of each impulsive buffer and derives a crest threshold tuned
/// to *their* claps, mic, and room — the research's "device-specific
/// calibration". No I/O here, so it's fully unit-testable.
public enum ClapCalibration {

    /// A captured buffer must be at least this impulsive to be considered a
    /// calibration clap candidate (filters ambient / speech).
    public static let candidateCrest: Float = 2.5

    /// At least this many clap candidates are needed for a valid calibration.
    public static let minCandidates = 2

    /// Margin below the user's weakest calibration clap (so real claps clear
    /// the threshold comfortably).
    public static let margin: Float = 0.7

    /// Clamp range for the derived threshold (never absurdly low/high).
    public static let range: ClosedRange<Float> = 2.0...5.0

    /// Derives a personalised crest threshold from captured buffer crests,
    /// or `nil` if too few claps were heard (calibration should be retried).
    public static func threshold(fromCrests crests: [Float]) -> Float? {
        let candidates = crests.filter { $0 >= candidateCrest }
        guard candidates.count >= minCandidates, let weakest = candidates.min() else {
            return nil
        }
        let derived = weakest * margin
        return min(max(derived, range.lowerBound), range.upperBound)
    }
}
