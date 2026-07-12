#if DEBUG
import AVFoundation
import CoreMotion
import SwiftUI

// MARK: - D0 Pocket Probe (DEBUG only — never ships)

/// On-device verification gate for Pocket Mode (shape note, PM-approved
/// 2026-07-12). Logs to `Documents/pocketdiag.csv` (notifdiag pattern).
/// The seven rows under test:
/// 1. proximity events fire while the screen is proximity-blanked
/// 2. app stays `.active` during blank
/// 3. auto-lock is suppressed by `isIdleTimerDisabled` during blank
/// 4. CoreMotion keeps delivering during blank
/// 5. audio plays during blank (beep on every proximity transition)
/// 6. battery cost over a ~30-min pocketed session
/// 7. proximity behavior right-side-up vs upside-down (gravity vector on
///    every transition and heartbeat — PM row, 2026-07-12)
@MainActor
@Observable
final class PocketProbeSession {

    private(set) var isRunning = false
    private(set) var lastEvent = "—"

    private let motion = CMMotionManager()
    private var heartbeatTask: Task<Void, Never>?
    private var proximityObserver: NSObjectProtocol?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var beepPlayer: AVAudioPlayer?
    private var sampleCount = 0
    private var latestGravity = (x: 0.0, y: 0.0, z: 0.0)

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        device.isProximityMonitoringEnabled = true
        UIApplication.shared.isIdleTimerDisabled = true

        prepareAudio()
        log("start battery=\(Int(device.batteryLevel * 100))%"
            + " proximitySupported=\(device.isProximityMonitoringEnabled)")

        // Rows 1 + 5 + 7: transition, beep, gravity stamp.
        proximityObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let covered = UIDevice.current.proximityState
                self.beepPlayer?.currentTime = 0
                self.beepPlayer?.play()
                self.log("proximity=\(covered ? "covered" : "uncovered")"
                         + " grav=\(self.gravityString()) appState=\(self.appStateString())")
                self.lastEvent = covered ? "covered" : "uncovered"
            }
        }

        // Row 3: if auto-lock (or anything else) backgrounds us, it shows here.
        let center = NotificationCenter.default
        for (name, tag) in [
            (UIApplication.willResignActiveNotification, "resignActive"),
            (UIApplication.didEnterBackgroundNotification, "background"),
            (UIApplication.didBecomeActiveNotification, "active")
        ] {
            lifecycleObservers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.log("lifecycle=\(tag)") }
            })
        }

        // Row 4: 10 Hz device motion, counted per heartbeat window.
        motion.deviceMotionUpdateInterval = 0.1
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            self.sampleCount += 1
            self.latestGravity = (data.gravity.x, data.gravity.y, data.gravity.z)
        }

        // Rows 2 + 4 + 7: 5 s heartbeat — appState, motion count, gravity.
        heartbeatTask = Task { @MainActor [weak self] in
            while let self, self.isRunning, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                self.log("hb samples=\(self.sampleCount) appState=\(self.appStateString())"
                         + " proximity=\(UIDevice.current.proximityState ? "covered" : "uncovered")"
                         + " grav=\(self.gravityString())")
                self.sampleCount = 0
            }
        }
    }

    func end() {
        guard isRunning else { return }
        log("end battery=\(Int(UIDevice.current.batteryLevel * 100))%")
        isRunning = false
        heartbeatTask?.cancel()
        heartbeatTask = nil
        motion.stopDeviceMotionUpdates()
        if let proximityObserver { NotificationCenter.default.removeObserver(proximityObserver) }
        proximityObserver = nil
        lifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        lifecycleObservers = []
        UIDevice.current.isProximityMonitoringEnabled = false
        UIApplication.shared.isIdleTimerDisabled = false
        beepPlayer = nil
    }

    // MARK: Helpers

    /// Row 5 needs an active audio session before the screen blanks.
    private func prepareAudio() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        if let url = Bundle.main.url(forResource: "beep.caf", withExtension: nil) {
            beepPlayer = try? AVAudioPlayer(contentsOf: url)
            beepPlayer?.prepareToPlay()
        }
    }

    private func gravityString() -> String {
        String(format: "%.2f,%.2f,%.2f", latestGravity.x, latestGravity.y, latestGravity.z)
    }

    private func appStateString() -> String {
        switch UIApplication.shared.applicationState {
        case .active: return "active"
        case .inactive: return "inactive"
        case .background: return "background"
        @unknown default: return "unknown"
        }
    }

    private func log(_ line: String) {
        guard let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pocketdiag.csv") else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url)
        }
    }
}

// MARK: - Probe UI

struct PocketProbeView: View {

    @State private var session = PocketProbeSession()

    var body: some View {
        VStack(spacing: 24) {
            Text(verbatim: "D0 Pocket Probe")
                .font(.title2.bold())
            Text(verbatim: """
            Start → pocket the phone SCREEN ON. \
            ~5 min right-side-up, ~5 min upside-down, walk ~30 min total. \
            Beeps on every cover/uncover. Pull out → End.
            """)
            .font(.footnote)
            .multilineTextAlignment(.center)

            Text(verbatim: "last: \(session.lastEvent)")
                .font(.caption.monospaced())

            Button(session.isRunning ? "End session" : "Start session") {
                session.isRunning ? session.end() : session.start()
            }
            .font(.title3.bold())
            .buttonStyle(.borderedProminent)
            .tint(session.isRunning ? .red : .green)
        }
        .padding()
        .onDisappear { session.end() }
    }
}
#endif
