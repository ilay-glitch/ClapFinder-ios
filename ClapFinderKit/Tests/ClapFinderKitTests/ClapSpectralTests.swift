#if canImport(Testing)
import Testing
import Foundation
@testable import ClapFinderKitAudio

// MARK: - ClapSpectral tests
//
// Two layers: (1) the reject-only invariant on the pure `confirm` decision —
// the structural safety property that the spectral stage can only downgrade a
// crest accept, never promote a non-peak; (2) feature extraction on synthetic
// clap/knock/speech-like signals.

@Suite("ClapSpectral")
struct ClapSpectralTests {

    // MARK: Reject-only invariant (the safety property)

    @Test("Spectral stage never promotes a non-peak — confirm(crestPeak: false) is always false")
    func rejectOnlyNeverPromotes() {
        // Sweep the whole feature space + both route states. A non-peak must
        // stay a non-peak no matter how 'clap-like' the spectrum looks.
        for hfrTimes in 0...10 {
            for sfmTimes in 0...10 {
                let hfr = Float(hfrTimes) / 10.0
                let sfm = Float(sfmTimes) / 10.0
                for route in [true, false] {
                    #expect(
                        ClapSpectral.confirm(crestPeak: false, hfr: hfr, sfm: sfm, routeAllowsSpectral: route) == false,
                        "spectral promoted a non-peak at hfr=\(hfr) sfm=\(sfm) route=\(route)"
                    )
                }
            }
        }
    }

    @Test("A bright, flat crest peak passes; a dull or tonal one is vetoed")
    func vetoBehaviour() {
        // bright + flat (clap-like) → passes
        #expect(ClapSpectral.confirm(crestPeak: true, hfr: 0.6, sfm: 0.5, routeAllowsSpectral: true))
        // dull (knock-like, low HFR) → vetoed
        #expect(!ClapSpectral.confirm(crestPeak: true, hfr: 0.05, sfm: 0.5, routeAllowsSpectral: true))
        // tonal (speech-like, low SFM) → vetoed
        #expect(!ClapSpectral.confirm(crestPeak: true, hfr: 0.6, sfm: 0.03, routeAllowsSpectral: true))
    }

    @Test("On non-built-in routes the veto is disabled — crest decides alone")
    func bluetoothFallback() {
        // Would be vetoed (dull AND tonal) on a built-in mic, but the BT route
        // falls back to crest-only → the crest peak stands.
        #expect(ClapSpectral.confirm(crestPeak: true, hfr: 0.01, sfm: 0.01, routeAllowsSpectral: false))
    }

    // MARK: Feature extraction (synthetic signals)

    private let sampleRate = 48_000.0
    private let frames = 1024

    // ⚠️ WHITE-NOISE ONLY — NOT representative of real mic buffers. White noise
    // is the one input whose every bin is ~equal, so the geomean SFM can't
    // collapse. On-device, band-limited real claps drive SFM → ~0 (geomean
    // dominated by near-zero HF bins). This test passing does NOT prove the
    // spectral feature works on the device. See SOUND_RECOGNITION_DESIGN.md §8.
    @Test("Broadband white noise → high HFR and high SFM (synthetic only)")
    func broadbandIsClapLike() {
        // Deterministic white-ish noise via a small LCG (no Math.random).
        var state: UInt32 = 22_222
        let samples: [Float] = (0..<frames).map { _ in
            state = state &* 1_664_525 &+ 1_013_904_223
            return Float(state) / Float(UInt32.max) * 2 - 1
        }
        let (hfr, sfm) = ClapSpectralAnalyzer().features(samples: samples, sampleRate: sampleRate)
        #expect(hfr > ClapSpectral.hfrThreshold)
        #expect(sfm > ClapSpectral.sfmThreshold)
        #expect(!ClapSpectral.shouldVeto(hfr: hfr, sfm: sfm))
    }

    @Test("Low-frequency tone (knock-like) → low HFR, vetoed")
    func lowToneIsKnockLike() {
        let samples: [Float] = (0..<frames).map { sinf(2 * .pi * 200 * Float($0) / Float(sampleRate)) }
        let (hfr, sfm) = ClapSpectralAnalyzer().features(samples: samples, sampleRate: sampleRate)
        #expect(hfr < ClapSpectral.hfrThreshold)
        #expect(ClapSpectral.shouldVeto(hfr: hfr, sfm: sfm))
    }

    @Test("Harmonic stack spanning the band (speech-like) → low SFM, vetoed by flatness")
    func harmonicIsSpeechLike() {
        // 500 Hz fundamental + 9 harmonics up to 5 kHz: energy reaches above the
        // 2 kHz cutoff (so HFR alone wouldn't veto), but the spectrum is a few
        // discrete lines → low flatness.
        let samples: [Float] = (0..<frames).map { index in
            var value: Float = 0
            for harmonic in 1...10 {
                value += sinf(2 * .pi * 500 * Float(harmonic) * Float(index) / Float(sampleRate))
            }
            return value / 10
        }
        let (hfr, sfm) = ClapSpectralAnalyzer().features(samples: samples, sampleRate: sampleRate)
        #expect(sfm < ClapSpectral.sfmThreshold)
        #expect(hfr >= ClapSpectral.hfrThreshold, "harmonics span the band, so SFM — not HFR — should be doing the rejecting")
        #expect(ClapSpectral.shouldVeto(hfr: hfr, sfm: sfm))
    }

    @Test("Degenerate input returns a zero feature pair")
    func degenerateInput() {
        let analyzer = ClapSpectralAnalyzer()
        #expect(analyzer.features(samples: [], sampleRate: sampleRate) == (0, 0))
        #expect(analyzer.features(samples: [0.5, 0.5], sampleRate: 0) == (0, 0))
    }
}
#endif
