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

    /// Margin below the user's weakest calibration clap. Was 0.7 (30 % below),
    /// which drove the threshold down into the inter-clap "release" band — the
    /// crest gate then saw almost everything as a peak and the double-clap FSM
    /// starved for releases (device session: 218/301 noRelease). 0.85 keeps the
    /// threshold just under the weakest clap so releases survive. See
    /// SOUND_RECOGNITION_DESIGN.md §7.
    public static let margin: Float = 0.85

    /// Clamp range for the derived threshold. Floor raised 2.0 → 2.5 so
    /// calibration can never derive a value down in the release/noise band
    /// (reach is worthless if the FSM can't pair the two claps).
    public static let range: ClosedRange<Float> = 2.5...5.0

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
