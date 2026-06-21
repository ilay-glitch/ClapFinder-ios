import Accelerate
import AVFoundation
import ClapFinderKitData
import Foundation
import OSLog

// MARK: - ClapDiagnostics

/// Measure-first instrumentation for clap detection (CLAP_DIAGNOSTICS.md).
///
/// Records, for every above-floor candidate the detector evaluates, the energy
/// / crest / transient-shape features and which gate decided it — so the real
/// feature-space separation between claps and non-claps can be read off-device
/// before any algorithm change. The decision path is never altered.
///
/// The pure parts (`Gate`, `Candidate`, `csvLine`, `transientShape`) compile in
/// all configurations so they stay CLI-testable; the stateful logging
/// `Session` is `#if DEBUG` only and is physically absent from Release builds.
public enum ClapDiagnostics {

    /// Runtime kill-switch for a debug session (default on in DEBUG).
    @MainActor public static var isEnabled = true

    /// Which `processSample` branch decided a candidate buffer.
    public enum Gate: String, Sendable {
        case lowCrest, spectralVeto, firstClap, staleWindow, tooClose, noRelease
        case accept = "ACCEPT"
    }

    /// Sample-resolution transient shape measured *inside* one buffer.
    public struct TransientShape: Sendable {
        /// Onset-sample → peak-sample, in milliseconds.
        public let attackMs: Float
        /// dB fall from the peak to the buffer tail, per millisecond.
        public let decayDbPerMs: Float
        /// Peak sits in the first/last 8 % of the buffer — the transient
        /// straddled a boundary, so `attackMs`/`decayDbPerMs` are truncated.
        public let peakAtEdge: Bool

        public static let none = TransientShape(attackMs: 0, decayDbPerMs: 0, peakAtEdge: false)
    }

    /// One logged candidate.
    public struct Candidate: Sendable {
        public let seq: Int
        public let rms, peak, dBFS, crest: Float
        /// Spectral features (v3). `-1` when not measured (crest below the
        /// pre-check, so the FFT was skipped — the buffer can't be a peak).
        public let hfr, sfm: Float
        public let shape: TransientShape
        public let threshold: Float
        public let calibrated: Bool
        public let sensitivity: Sensitivity
        public let gate: Gate
        /// Gap since the first clap (ms); `-1` when not part of a pair.
        public let dtMs: Double
    }

    public static let csvHeader =
        "seq,rms,peak,dBFS,crest,hfr,sfm,attackMs,decayDbPerMs,peakAtEdge,threshold,calibrated,sens,gate,dtMs"

    /// Formats one candidate as a single CSV row matching `csvHeader`.
    public static func csvLine(_ row: Candidate) -> String {
        func fmt(_ value: Float, _ places: Int = 3) -> String { String(format: "%.\(places)f", value) }
        return [
            String(row.seq),
            fmt(row.rms, 5), fmt(row.peak, 5), fmt(row.dBFS, 1), fmt(row.crest, 2),
            fmt(row.hfr, 3), fmt(row.sfm, 3),
            fmt(row.shape.attackMs, 2), fmt(row.shape.decayDbPerMs, 2),
            row.shape.peakAtEdge ? "1" : "0",
            fmt(row.threshold, 2),
            row.calibrated ? "1" : "0",
            row.sensitivity.rawValue,
            row.gate.rawValue,
            row.dtMs < 0 ? "" : String(format: "%.1f", row.dtMs)
        ].joined(separator: ",")
    }

    // MARK: Transient shape (pure)

    /// Fraction of peak magnitude marking the onset / decay knee.
    private static let kneeFraction: Float = 0.1
    /// Edge band: a peak within this fraction of either end is "at edge".
    private static let edgeBand: Float = 0.08

    /// Derives attack / decay from a buffer's magnitude envelope. Pure over the
    /// sample array so it is unit-testable without an `AVAudioPCMBuffer`.
    public static func transientShape(samples: [Float], sampleRate: Double) -> TransientShape {
        let count = samples.count
        guard count > 1, sampleRate > 0 else { return .none }

        var peakMag: Float = 0
        var peakIdx = 0
        for index in 0..<count {
            let mag = abs(samples[index])
            if mag > peakMag { peakMag = mag; peakIdx = index }
        }
        guard peakMag > 0 else { return .none }

        let msPerSample = Float(1000.0 / sampleRate)
        let knee = peakMag * kneeFraction

        // Attack: walk back from the peak to the last sample below the knee.
        var onsetIdx = peakIdx
        while onsetIdx > 0 && abs(samples[onsetIdx - 1]) >= knee { onsetIdx -= 1 }
        let attackMs = Float(peakIdx - onsetIdx) * msPerSample

        // Decay: dB fall from peak to the buffer tail, per ms.
        let tail = abs(samples[count - 1])
        let dbDrop = 20.0 * log10(peakMag / max(tail, Float(1e-10)))
        let decayMs = max(Float(count - 1 - peakIdx) * msPerSample, Float(1e-3))
        let decayDbPerMs = dbDrop / decayMs

        let edge = Int(Float(count) * edgeBand)
        let peakAtEdge = peakIdx <= edge || peakIdx >= (count - 1 - edge)

        return TransientShape(attackMs: attackMs, decayDbPerMs: decayDbPerMs, peakAtEdge: peakAtEdge)
    }

    /// Convenience over channel 0 of an audio buffer (DEBUG diagnostics path).
    public static func transientShape(buffer: AVAudioPCMBuffer) -> TransientShape {
        guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return .none }
        let count = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: data[0], count: count))
        return transientShape(samples: samples, sampleRate: buffer.format.sampleRate)
    }

#if DEBUG
    // MARK: Session (DEBUG only)

    /// Per-detector logging state: stages per-buffer measurements from the tap,
    /// then emits one CSV row per candidate when the FSM picks a gate.
    @MainActor
    final class Session {
        private var seq = 0
        private var threshold: Float = 0
        private var calibrated = false
        private var sensitivity: Sensitivity = .medium
        private var rms: Float = 0
        private var peak: Float = 0
        private var shape: TransientShape = .none
        private var headerEmitted = false

        /// Test hook — receives each emitted candidate (`@_spi(Testing)`).
        var onEmit: ((Candidate) -> Void)?

        private static let logger = Logger(
            subsystem: "com.appcentral.clapfinder",
            category: "ClapDiagnostics"
        )

        /// `Documents/clapdiag.csv` — pulled off-device via `devicectl copy`
        /// (os_log device streaming needs root). DEBUG-only.
        private let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("clapdiag.csv")

        /// Truncates the CSV + writes the header (fresh file per listen session).
        private func startFile() {
            guard let url = fileURL else { return }
            try? Data((ClapDiagnostics.csvHeader + "\n").utf8).write(to: url)
        }

        /// Appends one line to the CSV.
        private func appendLine(_ line: String) {
            guard let url = fileURL, let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data((line + "\n").utf8))
        }

        /// Called at listen-start with the thresholds actually in effect.
        func configure(threshold: Float, calibrated: Bool, sensitivity: Sensitivity) {
            self.threshold = threshold
            self.calibrated = calibrated
            self.sensitivity = sensitivity
            headerEmitted = false
            startFile()
        }

        /// Stages the current buffer's measurements (called just before
        /// `processSample`).
        func stage(rms: Float, peak: Float, shape: TransientShape) {
            self.rms = rms
            self.peak = peak
            self.shape = shape
        }

        /// Emits one CSV row for the branch the FSM took.
        func emit(_ gate: Gate, dBFS: Float, crest: Float, hfr: Float, sfm: Float, dtMs: Double = -1) {
            guard ClapDiagnostics.isEnabled else { return }
            if !headerEmitted {
                Self.logger.notice("\(ClapDiagnostics.csvHeader, privacy: .public)")
                headerEmitted = true
            }
            seq += 1
            let candidate = Candidate(
                seq: seq, rms: rms, peak: peak, dBFS: dBFS, crest: crest, hfr: hfr, sfm: sfm,
                shape: shape, threshold: threshold, calibrated: calibrated, sensitivity: sensitivity,
                gate: gate, dtMs: dtMs
            )
            let line = ClapDiagnostics.csvLine(candidate)
            Self.logger.notice("\(line, privacy: .public)")
            appendLine(line)
            onEmit?(candidate)
        }
    }
#endif
}
