#if canImport(Testing)
import Testing
import Foundation
@_spi(Testing) @testable import ClapFinderKitAudio
import ClapFinderKitData

// MARK: - ClapDiagnostics tests
//
// Pure formatting + transient-shape math, plus gate labelling verified through
// the *real* processSample FSM via the @_spi(Testing) onDiagnostic hook — so
// the labels can't drift from the branches they describe.

@Suite("ClapDiagnostics")
struct ClapDiagnosticsTests {

    // MARK: Transient shape (pure)

    @Test("A sharp, decaying transient has a short attack and a positive decay")
    func sharpTransientShape() {
        let sampleRate = 48_000.0
        var samples = [Float](repeating: 0, count: 100)
        for i in 45..<50 { samples[i] = Float(i - 44) / 5.0 }   // attack ramp 0→1
        samples[50] = 1.0                                        // peak
        for i in 51..<100 { samples[i] = expf(-Float(i - 50) / 10.0) }  // decay

        let shape = ClapDiagnostics.transientShape(samples: samples, sampleRate: sampleRate)
        #expect(shape.attackMs > 0)
        #expect(shape.attackMs < 1.0)            // a few samples at 48 kHz
        #expect(shape.decayDbPerMs > 0)          // falling after the peak
        #expect(!shape.peakAtEdge)               // peak at index 50 of 100
    }

    @Test("A peak at the buffer boundary is flagged peakAtEdge")
    func peakAtEdgeFlagged() {
        var samples = [Float](repeating: 0.05, count: 100)
        samples[0] = 1.0                          // peak in the first 8 %
        let shape = ClapDiagnostics.transientShape(samples: samples, sampleRate: 48_000)
        #expect(shape.peakAtEdge)
    }

    @Test("Degenerate buffers return a zero shape")
    func degenerateShape() {
        #expect(ClapDiagnostics.transientShape(samples: [], sampleRate: 48_000).attackMs == 0)
        #expect(ClapDiagnostics.transientShape(samples: [0.5], sampleRate: 0).attackMs == 0)
    }

    // MARK: CSV formatting

    @Test("csvLine has one field per header column and renders enums/flags")
    func csvLineMatchesHeader() {
        let candidate = ClapDiagnostics.Candidate(
            seq: 7,
            rms: 0.1, peak: 0.4, dBFS: -20, crest: 4.0, hfr: 0.55, sfm: 0.42,
            shape: .init(attackMs: 0.3, decayDbPerMs: 12.5, peakAtEdge: true),
            threshold: 2.8, calibrated: false, sensitivity: .medium,
            gate: .accept, dtMs: 150.0
        )
        let line = ClapDiagnostics.csvLine(candidate)
        let cols = line.split(separator: ",", omittingEmptySubsequences: false)
        let headerCols = ClapDiagnostics.csvHeader.split(separator: ",")
        #expect(cols.count == headerCols.count)
        #expect(line.contains("ACCEPT"))
        #expect(line.contains("medium"))
        #expect(cols[5] == "0.550")    // hfr
        #expect(cols[9] == "1")        // peakAtEdge
        #expect(cols[11] == "0")       // calibrated
    }

    @Test("dtMs renders empty when not part of a pair")
    func csvLineEmptyDt() {
        let candidate = ClapDiagnostics.Candidate(
            seq: 1, rms: 0, peak: 0, dBFS: -30, crest: 1.5, hfr: -1, sfm: -1, shape: .none,
            threshold: 2.8, calibrated: false, sensitivity: .low, gate: .lowCrest, dtMs: -1
        )
        let cols = ClapDiagnostics.csvLine(candidate).split(separator: ",", omittingEmptySubsequences: false)
        #expect(cols.last == "")
    }

#if DEBUG
    // MARK: Gate labelling (through the real FSM)

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    @MainActor
    private func capture(_ sensitivity: Sensitivity = .medium) -> (ClapDetector, Box) {
        let detector = ClapDetector()
        let box = Box()
        detector.setListeningForTesting(true, sensitivity: sensitivity)
        detector.onDiagnostic = { box.gates.append($0.gate); box.last = $0 }
        return (detector, box)
    }

    @Test("Above-floor non-impulsive buffer is labelled lowCrest")
    @MainActor
    func gateLowCrest() {
        let (detector, box) = capture()
        detector.processSample(dBFS: -30, crest: 1.5, at: at(0))   // above floor, crest < 2.8
        #expect(box.gates == [.lowCrest])
    }

    @Test("Below-floor (near-silence) buffers emit nothing")
    @MainActor
    func gateBelowFloorSilent() {
        let (detector, box) = capture()
        detector.processSample(dBFS: -60, crest: 5.0, at: at(0))   // below the −55 floor
        #expect(box.gates.isEmpty)
    }

    @Test("First peak is firstClap; a released, in-window second peak is ACCEPT with dtMs")
    @MainActor
    func gateAccept() {
        let (detector, box) = capture()
        detector.processSample(dBFS: -20, crest: 5.0, at: at(0.00))   // firstClap
        detector.processSample(dBFS: -30, crest: 1.0, at: at(0.05))   // release (lowCrest)
        detector.processSample(dBFS: -20, crest: 5.0, at: at(0.15))   // ACCEPT
        #expect(box.gates == [.firstClap, .lowCrest, .accept])
        #expect(abs((box.last?.dtMs ?? 0) - 150.0) < 0.01)
    }

    @Test("A second peak with no release in between is labelled noRelease")
    @MainActor
    func gateNoRelease() {
        let (detector, box) = capture()
        detector.processSample(dBFS: -20, crest: 5.0, at: at(0.00))   // firstClap
        detector.processSample(dBFS: -20, crest: 5.0, at: at(0.20))   // noRelease
        #expect(box.gates == [.firstClap, .noRelease])
    }

    private final class Box: @unchecked Sendable {
        var gates: [ClapDiagnostics.Gate] = []
        var last: ClapDiagnostics.Candidate?
    }
#endif
}
#endif
