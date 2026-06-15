#if canImport(Testing)
import Testing
import AVFoundation
import Foundation
@_spi(Testing) @testable import ClapFinderKitAudio
@testable import ClapFinderKitData

// MARK: - ClapDetector logic tests
//
// These exercise the pure detection state machine via the package-internal
// `processSample(dBFS:at:)` method with an injected clock — no AVAudioEngine
// or microphone needed, no sleeping. A real double-clap is two separate
// transients: above → below (release) → above, within the window and at
// least `minClapGapSeconds` apart.

@MainActor
struct ClapDetectorTests {

    private let t0 = Date(timeIntervalSince1970: 1_750_000_000)
    private func at(_ offset: TimeInterval) -> Date { t0.addingTimeInterval(offset) }

    private let loud: Float = -20    // above medium threshold (-40)
    private let quiet: Float = -60   // below threshold (a release)

    // MARK: Single clap — no fire

    @Test("Single clap above threshold does not fire onClapDetected")
    func singleClapNoFire() {
        let (detector, fired) = makeDetector()
        detector.processSample(dBFS: loud, at: at(0))
        #expect(!fired.value)
    }

    // MARK: Double clap — fires

    @Test("Two separate claps (release between, within window) fire once")
    func twoClapsFire() {
        let (detector, fired) = makeDetector()
        detector.processSample(dBFS: loud, at: at(0.00))    // clap 1
        detector.processSample(dBFS: quiet, at: at(0.05))   // release
        detector.processSample(dBFS: loud, at: at(0.15))    // clap 2 → fire
        #expect(fired.value)
    }

    // MARK: THE regression — continuous sound must not fire

    @Test("Continuous loud sound (no release) does NOT fire — the false-trigger bug")
    func continuousSoundDoesNotFire() {
        let (detector, fired) = makeDetector()
        // One sustained sound: consecutive ~23ms buffers all above threshold.
        for i in 0..<10 {
            detector.processSample(dBFS: loud, at: at(Double(i) * 0.023))
        }
        #expect(!fired.value, "Sustained sound was read as a double-clap")
    }

    @Test("Second clap without a release in between does NOT fire")
    func noReleaseNoFire() {
        let (detector, fired) = makeDetector()
        detector.processSample(dBFS: loud, at: at(0.00))   // clap 1
        detector.processSample(dBFS: loud, at: at(0.20))   // still no quiet sample between
        #expect(!fired.value)
    }

    @Test("Two claps closer than the minimum gap do NOT fire")
    func tooCloseNoFire() {
        let (detector, fired) = makeDetector()
        detector.processSample(dBFS: loud, at: at(0.00))
        detector.processSample(dBFS: quiet, at: at(0.01))
        detector.processSample(dBFS: loud, at: at(0.02))   // gap 0.02 < 0.08
        #expect(!fired.value)
    }

    // MARK: Cooldown — no double-fire

    @Test("Double-clap during cooldown does not fire again")
    func cooldownPreventsDoubleFire() {
        let (detector, fired) = makeDetector()
        detector.processSample(dBFS: loud, at: at(0.00))
        detector.processSample(dBFS: quiet, at: at(0.05))
        detector.processSample(dBFS: loud, at: at(0.15))   // fires once
        let firstCount = fired.count
        detector.processSample(dBFS: quiet, at: at(0.20))
        detector.processSample(dBFS: loud, at: at(0.30))   // ignored — cooldown active
        #expect(fired.count == firstCount)
    }

    // MARK: Below threshold — no fire

    @Test("Samples below threshold are ignored")
    func belowThresholdIgnored() {
        let (detector, fired) = makeDetector(sensitivity: .medium)
        detector.processSample(dBFS: -50, at: at(0.00))
        detector.processSample(dBFS: -50, at: at(0.15))
        #expect(!fired.value)
    }

    @Test("Threshold respects sensitivity level")
    func thresholdRespectsSensitivity() {
        // low sensitivity = threshold -30 dBFS; -35 is below it → never fires
        let (detectorLow, firedLow) = makeDetector(sensitivity: .low)
        detectorLow.processSample(dBFS: -35, at: at(0.00))
        detectorLow.processSample(dBFS: -60, at: at(0.05))
        detectorLow.processSample(dBFS: -35, at: at(0.15))
        #expect(!firedLow.value, "Low sensitivity should ignore -35 dBFS")

        // high sensitivity = threshold -50 dBFS; -45 is above it → fires on a real pair
        let (detectorHigh, firedHigh) = makeDetector(sensitivity: .high)
        detectorHigh.processSample(dBFS: -45, at: at(0.00))
        detectorHigh.processSample(dBFS: -60, at: at(0.05))
        detectorHigh.processSample(dBFS: -45, at: at(0.15))
        #expect(firedHigh.value, "High sensitivity should detect -45 dBFS")
    }

    // MARK: Window expiry — stale first clap resets

    @Test("A second clap after the window does not fire (stale first clap resets)")
    func staleFirstClapReplaced() {
        let (detector, fired) = makeDetector()
        detector.processSample(dBFS: loud, at: at(0.00))   // first clap
        detector.processSample(dBFS: quiet, at: at(0.05))  // release
        detector.processSample(dBFS: loud, at: at(0.70))   // 0.70 > 0.5 window → fresh first clap
        #expect(!fired.value)
    }

    // MARK: isListening guard

    @Test("processSample is ignored when isListening is false")
    func notListeningIgnored() {
        let (detector, fired) = makeDetector()
        // makeDetector() forces isListening on via the test hook — turn it
        // back off so the guard under test is actually exercised.
        detector.setListeningForTesting(false, sensitivity: .medium)
        detector.processSample(dBFS: loud, at: at(0.00))
        detector.processSample(dBFS: quiet, at: at(0.05))
        detector.processSample(dBFS: loud, at: at(0.15))
        #expect(!fired.value)
    }

    // MARK: rmsAmplitude helper

    @Test("rmsAmplitude returns 0 for empty buffer")
    func rmsAmplitudeEmptyBuffer() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 0)!
        buffer.frameLength = 0
        let rms = ClapDetector.rmsAmplitude(buffer: buffer)
        #expect(rms == 0)
    }

    @Test("rmsAmplitude of constant signal equals that constant")
    func rmsAmplitudeConstantSignal() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount: AVAudioFrameCount = 512
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Fill with constant amplitude 0.5
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) { samples[i] = 0.5 }

        let rms = ClapDetector.rmsAmplitude(buffer: buffer)
        #expect(abs(rms - 0.5) < 1e-5)
    }

    @Test("rmsAmplitude of silence is 0")
    func rmsAmplitudeSilence() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let frameCount: AVAudioFrameCount = 512
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        // Zero-fill (silence)
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) { samples[i] = 0 }

        let rms = ClapDetector.rmsAmplitude(buffer: buffer)
        #expect(rms == 0)
    }
}

// MARK: - Helpers

/// Box so we can mutate inside closures.
private final class Box<T>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

extension Box where T == Int {
    var boolValue: Bool { value > 0 }
}

private final class FireTracker: @unchecked Sendable {
    private(set) var count: Int = 0
    var value: Bool { count > 0 }
    func fire() { count += 1 }
}

/// Creates a `ClapDetector` with `isListening = true` (bypasses AVAudioEngine start)
/// and wires `onClapDetected` to a `FireTracker`.
@MainActor
private func makeDetector(sensitivity: Sensitivity = .medium) -> (ClapDetector, FireTracker) {
    let detector = ClapDetector()
    let tracker = FireTracker()
    detector.onClapDetected = { tracker.fire() }
    // Force `isListening` via the internal test hook so we bypass the real engine
    detector.setListeningForTesting(true, sensitivity: sensitivity)
    return (detector, tracker)
}
#endif
