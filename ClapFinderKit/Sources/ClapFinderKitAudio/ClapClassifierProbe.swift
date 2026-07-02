import AVFoundation
import Foundation
import OSLog

// MARK: - ClapClassifierProbe (DEBUG measurement only)

/// SoundAnalysis experiment probe (SOUND_ANALYSIS_INVESTIGATION.md §5).
///
/// Runs Apple's built-in sound classifier ALONGSIDE the live crest-only
/// detector and only LOGS — it never gates, vetoes, or replaces detection.
/// This is PR-15's recovered wrapper with the configuration PR-15 got wrong,
/// fixed: `windowDuration` 0.5 s (the built-in classifier's floor, vs the
/// ~0.975 s default that diluted a ~10 ms clap transient) and `overlapFactor`
/// 0.8 (results ~every 0.1 s, vs 0.5 → ~every 0.49 s).
///
/// Output: `Documents/clapsn.csv` — `t,topLabel,topConf,clapConf` per analysis
/// window, where `t` is seconds since `start()` (joins with clapdiag.csv's `t`)
/// and `clapConf` is the best confidence among clap-family labels.
#if DEBUG && os(iOS)
import SoundAnalysis

@MainActor
final class ClapClassifierProbe {

    /// Corrected knobs under test (PR-15 left both at defaults).
    static let windowSeconds = 0.5
    static let overlap = 0.8

    private static let clapLabels: Set<String> = ["clapping", "applause", "hands"]

    // Analysis runs off the main actor on its own serial queue (PR-15 pattern).
    nonisolated(unsafe) private var analyzer: SNAudioStreamAnalyzer?
    nonisolated(unsafe) private var observer: ProbeObserver?
    private let queue = DispatchQueue(label: "com.appcentral.clapfinder.snprobe")

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ClapSNProbe"
    )

    func start(format: AVAudioFormat) {
        let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            request.windowDuration = CMTimeMakeWithSeconds(Self.windowSeconds, preferredTimescale: 48_000)
            request.overlapFactor = Self.overlap
            let known = Set(request.knownClassifications)
            let accepted = Self.clapLabels.intersection(known)
            let obs = ProbeObserver(clapLabels: accepted)
            try streamAnalyzer.add(request, withObserver: obs)
            analyzer = streamAnalyzer
            observer = obs
            let labelList = accepted.sorted().joined(separator: ",")
            Self.logger.notice("""
            SN probe started — window \(Self.windowSeconds)s \
            overlap \(Self.overlap) labels \(labelList, privacy: .public)
            """)
        } catch {
            Self.logger.error("SN probe setup failed: \(error.localizedDescription)")
        }
    }

    /// Feeds one tap buffer (call from the audio tap; hops to the probe queue).
    nonisolated func analyze(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime) {
        guard let analyzer else { return }
        queue.async { analyzer.analyze(buffer, atAudioFramePosition: when.sampleTime) }
    }

    func stop() {
        analyzer?.removeAllRequests()
        analyzer = nil
        observer = nil
    }
}

// MARK: Observer → clapsn.csv

private final class ProbeObserver: NSObject, SNResultsObserving, @unchecked Sendable {
    private let clapLabels: Set<String>
    private let start = Date()
    private let fileURL = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("clapsn.csv")

    init(clapLabels: Set<String>) {
        self.clapLabels = clapLabels
        super.init()
        if let url = fileURL {
            try? Data("t,topLabel,topConf,clapConf\n".utf8).write(to: url)
        }
    }

    func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let result = result as? SNClassificationResult,
              let top = result.classifications.first else { return }
        let clapConf = result.classifications
            .filter { clapLabels.contains($0.identifier) }
            .map(\.confidence).max() ?? 0
        let elapsed = Date().timeIntervalSince(start)
        let line = String(format: "%.2f,%@,%.3f,%.3f\n", elapsed, top.identifier, top.confidence, clapConf)
        guard let url = fileURL, let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
}

#else

/// Non-DEBUG / non-iOS stub — the probe is measurement-only and never ships.
@MainActor
final class ClapClassifierProbe {
    func start(format: AVAudioFormat) {}
    nonisolated func analyze(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime) {}
    func stop() {}
}

#endif
