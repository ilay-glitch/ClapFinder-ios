import Accelerate
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
/// Not `Sendable` — the FFT setup is a raw pointer. Confine to one thread
/// (the audio tap), like `AVAudioEngine`.
public final class ClapSpectralAnalyzer {

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

    /// `(hfr, sfm)` for `samples`, zero-padded / truncated to the FFT size.
    /// Returns `(0, 0)` for empty input or a non-positive sample rate.
    ///
    /// Both features are *ratios*, so the FFT/packing scale factors cancel —
    /// no normalisation needed.
    public func features(samples: [Float], sampleRate: Double) -> (hfr: Float, sfm: Float) {
        guard sampleRate > 0, !samples.isEmpty else { return (0, 0) }
        let half = count / 2

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

        // Skip bin 0 (DC, and the zrip Nyquist packing) for both features.
        let band = Array(power[1..<half])
        var total: Float = 0
        vDSP_sve(band, 1, &total, vDSP_Length(band.count))
        guard total > 0 else { return (0, 0) }

        let binHz = Float(sampleRate) / Float(count)
        let cutoffBin = max(1, min(half - 1, Int(hfCutoffHz / binHz)))
        var highEnergy: Float = 0
        vDSP_sve(Array(power[cutoffBin..<half]), 1, &highEnergy, vDSP_Length(half - cutoffBin))
        let hfr = highEnergy / total

        // Spectral flatness = geometric mean / arithmetic mean over the band.
        var mean: Float = 0
        vDSP_meanv(band, 1, &mean, vDSP_Length(band.count))
        guard mean > 0 else { return (hfr, 0) }
        let logs = band.map { logf(max($0, Float(1e-20))) }
        var logMean: Float = 0
        vDSP_meanv(logs, 1, &logMean, vDSP_Length(logs.count))
        let sfm = expf(logMean) / mean

        return (hfr, sfm)
    }
}
