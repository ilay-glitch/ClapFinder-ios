import ClapFinderKitAds
import ClapFinderKitData
import ClapFinderKitDesign
import ClapFinderKitMotion
import SwiftUI

// MARK: - HomeView

/// The single-screen guard app UI (PIVOT.md — Touch Alert IS the product).
///
/// Layout (top → bottom), mirroring the winning creative:
///   Header (title + subtitle)
///   Guard hero — arm/disarm, the single big "tap to activate" action
///   Status label
///   Guard grid (the 16 alert sounds)
///   Sensitivity control
///   (idle-only ad banner at the bottom)
struct HomeView: View {

    @Environment(CatalogStore.self) private var catalogStore
    @Environment(TouchAlertCoordinator.self) private var touchAlert
    @Environment(InterstitialController.self) private var interstitials

    @State private var startError: String?
    /// Pre-permission explainer before the first arm (design §4.2 ruling).
    @AppStorage("touchAlert.hasSeenNotifExplainer") private var hasSeenNotifExplainer = false
    @State private var showNotifExplainer = false
    /// Volume tip: appears after the first completed guard session, until
    /// dismissed. (Was the LED-flash tip — rewritten per PIVOT.md §6c: the
    /// accessibility LED never fires for local notifications.)
    @AppStorage("home.hasCompletedFirstSession") private var hasCompletedFirstSession = false
    @AppStorage("home.volumeTipDismissed") private var volumeTipDismissed = false

    private let gridColumns = Array(repeating: GridItem(.fixed(80), spacing: CFSpacing.sm), count: 4)

    var body: some View {
        ZStack {
            CFColor.skyPrimary.ignoresSafeArea()

            // P3 slot: illustrated Home background (arrives with the PM's art).
            // Scrim keeps content readable; cards stay white on top.
            if let background = GuardAssets.homeBackground {
                Image(background)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(CFColor.skyPrimary.opacity(0.30).ignoresSafeArea())
                    .accessibilityHidden(true)
            }

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, CFSpacing.lg)

                    // P3 slot: guard mascot above the hero (shield when idle,
                    // watching pose while armed). Renders nothing until the art lands.
                    if let mascot = touchAlert.state == .disarmed
                        ? GuardAssets.heroDisarmed : GuardAssets.heroArmed {
                        Image(mascot)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 130)
                            .padding(.top, CFSpacing.md)
                            .accessibilityHidden(true)
                    }

                    TouchAlertHeroView(
                        state: touchAlert.state,
                        graceRemaining: touchAlert.graceRemaining,
                        gracePeriod: 5.0,
                        onTap: toggleTouchAlert
                    )
                    .padding(.top, CFSpacing.lg)

                    statusLabel
                        .padding(.top, CFSpacing.md)

                    // One-line model explanation (competitor gap: theirs is a
                    // buried paragraph). Idle only — armed states say it live.
                    if touchAlert.state == .disarmed {
                        Text(NSLocalizedString("touch.howItWorks", comment: ""))
                            .font(CFFont.caption())
                            .foregroundStyle(CFColor.textTertiary)
                            .multilineTextAlignment(.center)
                            .padding(.top, CFSpacing.xs)
                    }

                    if hasCompletedFirstSession && !volumeTipDismissed {
                        volumeTipCard
                            .padding(.top, CFSpacing.md)
                    }

                    if let err = startError {
                        Text(err) // allow-hardcoded-string until: pr-8
                            .font(CFFont.caption())
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.top, CFSpacing.xs)
                    }

                    guardGridSection
                        .padding(.top, CFSpacing.xl)

                    sensitivitySection
                        .padding(.top, CFSpacing.lg)

#if DEBUG
                    // Build provenance stamp — answers "which build is on the
                    // phone?" by looking at it (DEBUG only, never ships).
                    Text(verbatim: BuildStamp.value)
                        .font(CFFont.caption())
                        .foregroundStyle(CFColor.textTertiary)
                        .padding(.top, CFSpacing.md)
                        .padding(.bottom, CFSpacing.xxl)
#else
                    Color.clear.frame(height: CFSpacing.xxl)
#endif
                }
                .padding(.horizontal, CFSpacing.md)
            }
            .scrollIndicators(.hidden)

            // Banner: bottom of Home ONLY, idle-only (ADS_DESIGN.md D3) —
            // hidden while the guard is armed or alarming.
            if touchAlert.state == .disarmed {
                VStack {
                    Spacer()
                    BannerAdView()
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: touchAlert.state == .disarmed)
        .overlay {
            if touchAlert.state == .alarming {
                AlarmOverlayView(animal: touchAlert.armedAnimal) {
                    touchAlert.disarm()
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: touchAlert.state == .alarming)
        .alert(
            Text(NSLocalizedString("touch.notifExplainer.title", comment: "")),
            isPresented: $showNotifExplainer
        ) {
            Button(NSLocalizedString("touch.notifExplainer.ok", comment: "")) { // allow-hardcoded-string until: pr-11
                hasSeenNotifExplainer = true
                armTouchAlert()
            }
        } message: {
            Text(NSLocalizedString("touch.notifExplainer.body", comment: ""))
        }
    }

    // MARK: Sections

    private var headerSection: some View {
        VStack(spacing: CFSpacing.xs) {
            Text(NSLocalizedString("home.title", comment: ""))
                .font(CFFont.display())
                .foregroundStyle(CFColor.textPrimary)

            Text(NSLocalizedString("home.subtitle", comment: ""))
                .font(CFFont.callout())
                .foregroundStyle(CFColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        Group {
            switch touchAlert.state {
            case .disarmed:
                Text(NSLocalizedString("touch.status.disarmed", comment: ""))
                    .foregroundStyle(CFColor.textTertiary)
            case .grace:
                Text(NSLocalizedString("touch.status.grace", comment: ""))
                    .foregroundStyle(CFColor.textSecondary)
            case .monitoring:
                HStack(spacing: CFSpacing.xs) {
                    Circle()
                        .fill(CFColor.listeningActive)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("touch.status.monitoring", comment: ""))
                        .foregroundStyle(CFColor.listeningActive)
                }
            case .alarming:
                Text(NSLocalizedString("touch.status.alarming", comment: ""))
                    .foregroundStyle(.red)
            }
        }
        .font(CFFont.callout())
    }

    private var guardGridSection: some View {
        VStack(alignment: .leading, spacing: CFSpacing.md) {
            Text(NSLocalizedString("animals.header", comment: ""))
                .font(CFFont.headline())
                .foregroundStyle(CFColor.textPrimary)

            LazyVGrid(columns: gridColumns, spacing: CFSpacing.sm) {
                ForEach(catalogStore.animals) { animal in
                    AnimalCardView(
                        animal: animal,
                        isSelected: catalogStore.selectedAnimalID == animal.id
                    ) {
                        selectGuard(animal)
                    }
                }
            }
        }
    }

    /// One-time volume tip: the alarm's loudness is the locked-phone defense
    /// (PIVOT.md §6b/§6c), and it plays at media volume via the `.playback`
    /// session — worth surfacing once.
    private var volumeTipCard: some View {
        HStack(alignment: .top, spacing: CFSpacing.sm) {
            VStack(alignment: .leading, spacing: CFSpacing.xs) {
                Text(NSLocalizedString("home.volumeTip.title", comment: ""))
                    .font(CFFont.headline())
                    .foregroundStyle(CFColor.textPrimary)
                Text(NSLocalizedString("home.volumeTip.body", comment: ""))
                    .font(CFFont.caption())
                    .foregroundStyle(CFColor.textSecondary)
            }
            Spacer()
            Button(NSLocalizedString("home.volumeTip.dismiss", comment: "")) {
                volumeTipDismissed = true
            }
            .font(CFFont.caption())
            .foregroundStyle(CFColor.ctaBlue)
        }
        .padding(CFSpacing.md)
        .background(CFColor.cream, in: RoundedRectangle(cornerRadius: CFRadius.card, style: .continuous))
    }

    private var sensitivitySection: some View {
        @Bindable var store = catalogStore
        return SensitivityControlView(sensitivity: $store.sensitivity)
    }

    // MARK: Actions

    private func toggleTouchAlert() {
        startError = nil
        if touchAlert.state == .disarmed {
            if hasSeenNotifExplainer {
                armTouchAlert()
            } else {
                showNotifExplainer = true
            }
        } else {
            // D1-v2 (ADS_DESIGN, PM 2026-07-08): a use = a completed guard
            // session — user-disarm from MONITORING only. Grace-cancels don't
            // count; the alarm-dismiss path (AlarmOverlayView) never reaches
            // here. Attempt fires at disarm-idle, policy re-checks all flags.
            let completedSession = touchAlert.state == .monitoring
            touchAlert.disarm()
            if completedSession {
                hasCompletedFirstSession = true
                interstitials.recordUse()
                interstitials.attemptPresentation(
                    isDetectionActive: false,
                    isAlarmActive: touchAlert.state != .disarmed
                )
            }
        }
    }

    private func armTouchAlert() {
        guard let animal = catalogStore.selectedAnimal else { return }
        do {
            try touchAlert.arm(animal: animal, sensitivity: catalogStore.sensitivity)
        } catch {
            startError = error.localizedDescription
        }
    }

    /// Persists the guard choice. While armed, monitoring continues with the
    /// sound it was armed with; the new choice takes effect on the next arm.
    private func selectGuard(_ animal: Animal) {
        catalogStore.selectedAnimalID = animal.id
    }
}
