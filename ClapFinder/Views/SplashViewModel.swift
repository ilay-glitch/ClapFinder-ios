import ClapFinderKitAds
import Foundation
import Observation
import OSLog

// MARK: - AdSession

/// Process-lifetime ad facts (rule 3: max one app open ad per session).
@MainActor
enum AdSession {
    static var appOpenAdShownThisSession = false
}

// MARK: - SplashViewModel

/// Impure shell around `SplashStateMachine` (SPLASH_DESIGN.md §7, §9).
///
/// Owns the real clocks (1.5 s minimum timer, 5 s ad timeout, progress
/// ticker), the GMA loader, persistence, and analytics. Every decision
/// lives in the pure layer; this type only feeds it events and reacts
/// to its state.
@Observable
@MainActor
final class SplashViewModel {

    // MARK: Observable state

    private(set) var progress: Double = 0
    private(set) var finished = false

    /// "This action can contain ads" shows only while an ad request is
    /// actually in flight (§2, §6) — never on first launch.
    var showAdDisclaimer: Bool {
        switch machine.adPhase {
        case .requesting, .loaded, .presenting:
            return true
        case .idle, .skipped, .failed, .timedOut, .dismissed:
            return false
        }
    }

    var percent: Int {
        Int((progress * 100).rounded())
    }

    /// Fired exactly once when the splash hands off to Home.
    var onFinished: (@MainActor () -> Void)?

    // MARK: Constants (SPLASH_DESIGN.md §4)

    private let minimumDuration: TimeInterval = 1.5
    private let adTimeout: TimeInterval = 5.0

    // MARK: Dependencies

    private var machine = SplashStateMachine()
    private let policy: AppOpenAdPolicy
    private let store: AppOpenAdStore
    private let analytics: AnalyticsClient
    private let adLoader = AppOpenAdLoader()

    private let isFirstLaunch: Bool
    private let startedAt = Date()
    private var started = false
    private var presenting = false
    private var tasks: [Task<Void, Never>] = []

    private static let logger = Logger(
        subsystem: "com.appcentral.clapfinder",
        category: "Splash"
    )

    // MARK: Init

    init(
        policy: AppOpenAdPolicy = AppOpenAdPolicy(),
        store: AppOpenAdStore = UserDefaultsAppOpenAdStore(),
        analytics: AnalyticsClient = OSLogAnalyticsClient()
    ) {
        self.policy = policy
        self.store = store
        self.analytics = analytics
        self.isFirstLaunch = !store.hasCompletedFirstLaunch
    }

    // MARK: Lifecycle

    /// Idempotent — a background/foreground cycle mid-splash re-calls
    /// this without restarting timers or the ad request (§4).
    func start() {
        guard !started else { return }
        started = true

        analytics.log(SplashAnalytics.splashShown(coldLaunch: true, firstLaunch: isFirstLaunch))

        // Catalog is loaded synchronously by CatalogStore's init upstream.
        apply(.catalogLoaded)

        let decision = policy.decide(
            isFirstLaunch: isFirstLaunch,
            shownThisSession: AdSession.appOpenAdShownThisSession,
            lastShownAt: store.lastAdShownAt
        )
        apply(.adDecided(decision))
        if machine.wantsAdRequest {
            requestAd()
        }

        startMinimumTimer()
        startProgressTicker()
    }

    // MARK: Private — timers

    private func startMinimumTimer() {
        tasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(minimumDuration))
            guard !Task.isCancelled else { return }
            self.apply(.minTimerFired)
        })
    }

    private func startProgressTicker() {
        tasks.append(Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, !self.finished else { return }
                self.refreshProgress()
                try? await Task.sleep(for: .milliseconds(50))
            }
        })
    }

    private func refreshProgress() {
        progress = SplashStateMachine.progress(
            elapsed: Date().timeIntervalSince(startedAt),
            minDuration: minimumDuration,
            catalogLoaded: machine.catalogLoaded,
            adResolved: machine.adResolved,
            previous: progress
        )
    }

    // MARK: Private — ad request

    private func requestAd() {
        analytics.log(SplashAnalytics.adRequested(attAuthorized: adLoader.isATTAuthorized))

        tasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            let error = await self.adLoader.load()
            guard !Task.isCancelled else { return }
            if let error {
                self.analytics.log(SplashAnalytics.adFailed(errorReason: error))
                self.apply(.adFailed(error))
            } else {
                self.apply(.adLoaded)
            }
        })

        tasks.append(Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(adTimeout))
            guard !Task.isCancelled, self.machine.adPhase == .requesting else { return }
            let elapsed = Int(Date().timeIntervalSince(self.startedAt) * 1000)
            self.analytics.log(SplashAnalytics.adTimeout(elapsedMs: elapsed))
            self.adLoader.discard()
            self.apply(.adTimedOut)
        })
    }

    // MARK: Private — state machine

    private func apply(_ event: SplashStateMachine.Event) {
        machine.apply(event)
        refreshProgress()

        switch machine.state {
        case .presentingAd:
            presentAdIfNeeded()
        case .finished(let adShown, let skipReason):
            finish(adShown: adShown, skipReason: skipReason)
        case .loading:
            break
        }
    }

    private func presentAdIfNeeded() {
        guard !presenting else { return }
        presenting = true

        analytics.log(SplashAnalytics.adShown())
        store.lastAdShownAt = Date()
        AdSession.appOpenAdShownThisSession = true

        adLoader.present { [weak self] in
            self?.apply(.adDismissed)
        }
    }

    private func finish(adShown: Bool, skipReason: AdSkipReason) {
        guard !finished else { return }
        finished = true

        tasks.forEach { $0.cancel() }
        tasks.removeAll()
        progress = 1.0
        store.hasCompletedFirstLaunch = true

        let duration = Int(Date().timeIntervalSince(startedAt) * 1000)
        analytics.log(SplashAnalytics.splashCompleted(
            durationMs: duration,
            adShown: adShown,
            skipReason: skipReason
        ))
        Self.logger.info("Splash finished — adShown=\(adShown), skip=\(skipReason.rawValue)")

        onFinished?()
    }
}
