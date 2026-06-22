import Accelerate
import AVFoundation
import Foundation

// MARK: - ClapSpectral (decision logic — pure, FFT-free)

/// The reject-only spectral stage of the hybrid detector
/// (SOUND_RECOGNITION_DESIGN.md v3). It layers on top of the unchanged crest
/// onset gate: a buffer the crest gate accepted is *vetoed* if it looks like a
/// knock (dull — low HF energy ratio) or speech (tonal — low spectral
/// flatness). It can only downgrade an accept; it never promotes a non-peak.
///
/// Thresholds are deliberately permissive (favor clap recall) and tuned from
/// the on-device `hfr`/`sfm` diagnostics — these are starting values.
public enum ClapSpectral {

    /// Below this HF-energy ratio a candidate is "dull" → knock. (Starting value.)
    public static let hfrThreshold: Float = 0.20
    /// Below this spectral flatness a candidate is "tonal" → speech. (Starting value.)
    public static let sfmThreshold: Float = 0.15

    /// The FFT runs only when crest clears this (the lowest crest any threshold
    /// — incl. calibration's 2.0 clamp — could call a peak), so it is evaluated
    /// rarely, not every buffer. A buffer below this can never be a peak, so its
    /// spectral features are never consulted.
    public static let preCheckCrest: Float = 2.0

    /// `true` ⇒ reject as a non-clap. Permissive: only clearly dull OR clearly
    /// tonal candidates are vetoed; anything ambiguous passes.
    public static func shouldVeto(hfr: Float, sfm: Float) -> Bool {
        hfr < hfrThreshold || sfm < sfmThreshold
    }

    /// Final reject-only decision for a buffer.
    ///
    /// - `crestPeak`: did the unchanged crest onset gate accept this buffer?
    /// - `routeAllowsSpectral`: `false` on Bluetooth / non-built-in mics, where
    ///   HF roll-off would veto real claps — there we fall back to crest-only
    ///   (SOUND_RECOGNITION_DESIGN.md §11).
    ///
    /// The structural safety property (see `ClapSpectralTests`): when
    /// `crestPeak == false` the result is **always** `false` — the spectral
    /// stage can never turn a non-peak into a peak.
    public static func confirm(
        crestPeak: Bool,
        hfr: Float,
        sfm: Float,
        routeAllowsSpectral: Bool
    ) -> Bool {
        guard crestPeak else { return false }          // reject-only: never promote
        guard routeAllowsSpectral else { return true } // BT fallback: crest decides
        return !shouldVeto(hfr: hfr, sfm: sfm)
    }
}

// MARK: - ClapSpectralAnalyzer (FFT feature extraction)

/// Extracts the two spectral features from one onset buffer via a single
/// reused vDSP real FFT. Holds the FFT setup + Hann window so the hot path
/// allocates nothing structural; created once per detector.
///
/// `@unchecked Sendable`: the instance is immutable after `init` (FFT setup +
/// window are read-only) and `features` allocates only local buffers — it
/// mutates no shared state — so it is safe to call from the audio tap.
public final class ClapSpectralAnalyzer: @unchecked Sendable {

    private let log2n: vDSP_Length
    private let count: Int
    private let setup: FFTSetup
    private let window: [Float]
    /// Frequency above which energy counts as "high" for the HF ratio.
    public let hfCutoffHz: Float

    public init(maxFrames: Int = 1024, hfCutoffHz: Float = 2000) {
        var power2: vDSP_Length = 1
        while (1 << power2) < maxFrames { power2 += 1 }
        self.log2n = power2
        self.count = 1 << power2
        self.hfCutoffHz = hfCutoffHz
        self.setup = vDSP_create_fftsetup(power2, FFTRadix(kFFTRadix2))!
        var win = [Float](repeating: 0, count: count)
        vDSP_hann_window(&win, vDSP_Length(count), Int32(vDSP_HANN_NORM))
        self.window = win
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Per-candidate features. `hfr`/`sfm` drive the (currently OFF) veto;
    /// `centroidHz`/`rolloffHz`/`zcr` are v4 diagnostics, logged-only for the
    /// claps-vs-noise tuning session (SOUND_RECOGNITION_DESIGN.md §14.6).
    /// `-1` = not measured.
    public struct SpectralFeatures: Sendable {
        public let hfr, sfm, centroidHz, rolloffHz, zcr: Float
        public static let zero = SpectralFeatures(hfr: 0, sfm: 0, centroidHz: 0, rolloffHz: 0, zcr: 0)
        public static let notMeasured = SpectralFeatures(hfr: -1, sfm: -1, centroidHz: -1, rolloffHz: -1, zcr: -1)
    }

    /// Features for `samples`, zero-padded / truncated to the FFT size.
    /// Ratios (`hfr`/`sfm`) are scale-free; `centroidHz`/`rolloffHz` are in Hz;
    /// `zcr` is the time-domain crossing fraction (0…1).
    public func features(samples: [Float], sampleRate: Double) -> SpectralFeatures {
        guard sampleRate > 0, !samples.isEmpty else { return .zero }
        let half = count / 2

        // ZCR — time-domain, on the raw (un-windowed) samples.
        var crossings = 0
        for idx in 1..<samples.count where (samples[idx - 1] < 0) != (samples[idx] < 0) { crossings += 1 }
        let zcr = Float(crossings) / Float(max(samples.count - 1, 1))

        var windowed = [Float](repeating: 0, count: count)
        let usable = min(samples.count, count)
        vDSP_vmul(samples, 1, window, 1, &windowed, 1, vDSP_Length(usable))

        var realp = [Float](repeating: 0, count: half)
        var imagp = [Float](repeating: 0, count: half)
        var power = [Float](repeating: 0, count: half)

        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var split = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                windowed.withUnsafeBufferPointer { wptr in
                    wptr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { cptr in
                        vDSP_ctoz(cptr, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvmags(&split, 1, &power, 1, vDSP_Length(half))
            }
        }

        // Skip bin 0 (DC, and the zrip Nyquist packing).
        let band = Array(power[1..<half])
        let binHz = Float(sampleRate) / Float(count)
        var total: Float = 0
        vDSP_sve(band, 1, &total, vDSP_Length(band.count))
        guard total > 0 else {
            return SpectralFeatures(hfr: 0, sfm: 0, centroidHz: 0, rolloffHz: 0, zcr: zcr)
        }

        let cutoffBin = max(1, min(half - 1, Int(hfCutoffHz / binHz)))
        var highEnergy: Float = 0
        vDSP_sve(Array(power[cutoffBin..<half]), 1, &highEnergy, vDSP_Length(half - cutoffBin))
        let hfr = highEnergy / total

        // Spectral flatness (v3, broken on real claps — kept logged; §13.1).
        var mean: Float = 0
        vDSP_meanv(band, 1, &mean, vDSP_Length(band.count))
        var sfm: Float = 0
        if mean > 0 {
            let logs = band.map { logf(max($0, Float(1e-20))) }
            var logMean: Float = 0
            vDSP_meanv(logs, 1, &logMean, vDSP_Length(logs.count))
            sfm = expf(logMean) / mean
        }

        // Centroid (weighted mean bin — collapse-immune) + 85% rolloff.
        let (centroidHz, rolloffHz) = Self.centroidAndRolloff(band: band, total: total, binHz: binHz)
        return SpectralFeatures(hfr: hfr, sfm: sfm, centroidHz: centroidHz, rolloffHz: rolloffHz, zcr: zcr)
    }

    /// Energy-weighted mean-frequency (centroid) and 85 % rolloff, in Hz, over
    /// the band (which starts at FFT bin 1).
    private static func centroidAndRolloff(band: [Float], total: Float, binHz: Float) -> (Float, Float) {
        var weighted: Float = 0
        var cumulative: Float = 0
        var rolloffBin = band.count
        var rolloffFound = false
        let target = total * 0.85
        for bandIdx in 0..<band.count {
            let bin = bandIdx + 1
            weighted += Float(bin) * band[bandIdx]
            cumulative += band[bandIdx]
            if !rolloffFound && cumulative >= target { rolloffBin = bin; rolloffFound = true }
        }
        return ((weighted / total) * binHz, Float(rolloffBin) * binHz)
    }

    /// Convenience over channel 0 of an audio buffer (the tap's hot path).
    public func features(buffer: AVAudioPCMBuffer) -> SpectralFeatures {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return .zero }
        let frames = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: data[0], count: frames))
        return features(samples: samples, sampleRate: buffer.format.sampleRate)
    }
}
