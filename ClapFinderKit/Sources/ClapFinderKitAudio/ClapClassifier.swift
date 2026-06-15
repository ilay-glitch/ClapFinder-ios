import AVFoundation
import Foundation
import OSLog

#if os(iOS)
import SoundAnalysis

// MARK: - ClapClassifier

/// Wraps Apple's on-device SoundAnalysis built-in classifier to recognize
/// claps by *identity*, not just loudness (SOUND_RECOGNITION_DESIGN.md §1).
///
/// Tap buffers are streamed into `SNAudioStreamAnalyzer`; whenever a
/// clap-family label (resolved at runtime from `knownClassifications`)
/// crosses into the results, `onClap(confidence, time)` fires on the main
/// actor. The caller's gesture machine still requires two events for a
/// double-clap.
@MainActor
public final class ClapClassifier {

    /// Called with the best clap-family confidence (0…1) per analyzed window.
    public var onClap: (@MainActor (Double, Date) -> Void)?

    // Analysis runs off the main actor on its own serial queue.
    nonisolated(unsafe) private var analyzer: SNAudioStreamAnalyzer?
    nonisolated(unsafe) private var observer: ClapResultsObserver?
    private let analysisQueue = DispatchQueue(label: "com.appcentral.clapfinder.soundanalysis")

    nonisolated private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "ClapClassifier"
    )

    /// Clap-family labels we accept, intersected with what the classifier
    /// actually knows (so we never reference a label that doesn't exist).
    private static let clapLabelCandidates: Set<String> = ["clapping", "applause", "hands"]

    public init() {}

    /// Prepares the analyzer for the given input format and starts classifying.
    public func start(format: AVAudioFormat) {
        let streamAnalyzer = SNAudioStreamAnalyzer(format: format)
        do {
            let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
            let known = Set(request.knownClassifications)
            let accepted = Self.clapLabelCandidates.intersection(known)
            guard !accepted.isEmpty else {
                Self.logger.error("No clap-family labels in classifier — recognition disabled")
                return
            }
            let obs = ClapResultsObserver(acceptedLabels: accepted) { [weak self] confidence, date in
                Task { @MainActor in self?.onClap?(confidence, date) }
            }
            try streamAnalyzer.add(request, withObserver: obs)
            analyzer = streamAnalyzer
            observer = obs
            Self.logger.info("Clap classifier started (labels: \(accepted.sorted().joined(separator: ",")))")
        } catch {
            Self.logger.error("SoundAnalysis setup failed: \(error.localizedDescription)")
        }
    }

    /// Feeds one tap buffer to the analyzer (call from the audio tap).
    public nonisolated func analyze(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime) {
        guard let analyzer else { return }
        analysisQueue.async {
            analyzer.analyze(buffer, atAudioFramePosition: when.sampleTime)
        }
    }

    public func stop() {
        analyzer?.removeAllRequests()
        analyzer = nil
        observer = nil
    }
}

// MARK: - Results observer

private final class ClapResultsObserver: NSObject, SNResultsObserving {
    private let acceptedLabels: Set<String>
    private let onClap: (Double, Date) -> Void

    init(acceptedLabels: Set<String>, onClap: @escaping (Double, Date) -> Void) {
        self.acceptedLabels = acceptedLabels
        self.onClap = onClap
    }

    func request(_ request: any SNRequest, didProduce result: any SNResult) {
        guard let result = result as? SNClassificationResult else { return }
        let best = result.classifications
            .filter { acceptedLabels.contains($0.identifier) }
            .map(\.confidence)
            .max()
        if let best {
            onClap(best, Date())
        }
    }
}

#else

// MARK: - macOS stub (SoundAnalysis is iOS-only)

@MainActor
public final class ClapClassifier {
    public var onClap: (@MainActor (Double, Date) -> Void)?
    public init() {}
    public func start(format: AVAudioFormat) {}
    public nonisolated func analyze(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime) {}
    public func stop() {}
}

#endif
