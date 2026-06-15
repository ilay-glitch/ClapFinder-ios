#if canImport(Testing)
import Testing
import Foundation
@testable import ClapFinderKitData

// MARK: - ClapCalibration logic tests
//
// Pure derivation: from the crest factors captured during a calibration
// window, derive a personalised threshold = weakest qualifying clap × margin,
// clamped to `range`. Too few clap candidates → nil (retry).

@Suite("ClapCalibration")
struct ClapCalibrationTests {

    @Test("Derives threshold from the weakest clap, with margin")
    func derivesFromWeakest() {
        // Candidates ≥ 2.5: 4.0, 5.0, 3.0 → weakest 3.0 × 0.7 = 2.1.
        let result = ClapCalibration.threshold(fromCrests: [4.0, 5.0, 3.0])
        #expect(result != nil)
        #expect(abs((result ?? 0) - 2.1) < 0.0001)
    }

    @Test("Ignores sub-candidate crests (ambient / speech)")
    func ignoresNonCandidates() {
        // Only 4.0 and 4.2 qualify (≥ 2.5); 1.2/2.0 are filtered out.
        // weakest 4.0 × 0.7 = 2.8.
        let result = ClapCalibration.threshold(fromCrests: [1.2, 2.0, 4.0, 4.2])
        #expect(result != nil)
        #expect(abs((result ?? 0) - 2.8) < 0.0001)
    }

    @Test("Returns nil when too few claps were heard")
    func tooFewClaps() {
        #expect(ClapCalibration.threshold(fromCrests: [1.0, 2.0]) == nil)
        #expect(ClapCalibration.threshold(fromCrests: [4.0]) == nil)
        #expect(ClapCalibration.threshold(fromCrests: []) == nil)
    }

    @Test("Clamps the derived threshold to the valid range")
    func clampsToRange() {
        // Very strong claps would derive > 5.0 → clamped to upper bound.
        let high = ClapCalibration.threshold(fromCrests: [10.0, 12.0])
        #expect(high == ClapCalibration.range.upperBound)

        // Barely-qualifying claps derive 2.5 × 0.7 = 1.75 → clamped to 2.0.
        let low = ClapCalibration.threshold(fromCrests: [2.5, 2.5])
        #expect(low == ClapCalibration.range.lowerBound)
    }
}
#endif
