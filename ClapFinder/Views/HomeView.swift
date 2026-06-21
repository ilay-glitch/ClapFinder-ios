import ClapFinderKitAudio
import ClapFinderKitData
import ClapFinderKitDesign
import ClapFinderKitMotion
import SwiftUI

// MARK: - HomeView

/// The single-screen app UI.
///
/// Layout (top → bottom):
///   Header (title + subtitle)
///   Toggle hero (PulseRings + ListeningToggle)
///   Status label
///   Animal grid
///   Sensitivity control
///   (Ad banner — Phase 2)
struct HomeView: View {

    @Environment(CatalogStore.self) private var catalogStore
    @Environment(ResponseCoordinator.self) private var coordinator
    @Environment(TouchAlertCoordinator.self) private var touchAlert
    @Environment(InterstitialController.self) private var interstitials

    /// Tracks the brief "Found you!" flash after a clap is detected.
    @State private var showFoundState = false
    @State private var startError: String?
    @State private var mode: DetectionMode = .clap
    /// Pre-permission explainer before the first arm (design §4.2 ruling).
    @AppStorage("touchAlert.hasSeenNotifExplainer") private var hasSeenNotifExplainer = false
    @State private var showNotifExplainer = false
    @State private var calibrator = ClapCalibrationController()
    @State private var showCalibration = false

    private let gridColumns = Array(repeating: GridItem(.fixed(80), spacing: CFSpacing.sm), count: 4)

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────
            CFColor.skyPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, CFSpacing.lg)

                    ModeSwitcherView(mode: $mode)
                        .padding(.top, CFSpacing.md)

                    heroSection
                        .padding(.top, CFSpacing.lg)

                    statusLabel
                        .padding(.top, CFSpacing.md)

                    if let err = startError {
                        Text(err) // allow-hardcoded-string until: pr-8
                            .font(CFFont.caption())
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.top, CFSpacing.xs)
                    }

                    animalSection
                        .padding(.top, CFSpacing.xl)

                    sensitivitySection
                        .padding(.top, CFSpacing.lg)

                    if mode == .clap {
                        calibrateSection
                            .padding(.top, CFSpacing.md)
                            .padding(.bottom, CFSpacing.xxl)
                    } else {
                        Color.clear.frame(height: CFSpacing.xxl)
                    }
                }
                .padding(.horizontal, CFSpacing.md)
            }
            .scrollIndicators(.hidden)

            // Banner: bottom of Home ONLY, idle-only (ADS_DESIGN.md D3) —
            // hidden while listening and while the touch alert is armed.
            if !coordinator.isActive && touchAlert.state == .disarmed {
                VStack {
                    Spacer()
                    BannerAdView()
                }
                .ignoresSafeArea(edges: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coordinator.isActive)
        .animation(.easeInOut(duration: 0.25), value: touchAlert.state == .disarmed)
        .onChange(of: coordinator.lastTriggeredAnimal) { _, animal in
            guard animal != nil else { return }
            showFoundState = true
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                showFoundState = false
            }
        }
        .onChange(of: mode) { _, newMode in
            // Modes are exclusive — one detection pipeline at a time (design §3).
            switch newMode {
            case .clap:
                if touchAlert.state != .disarmed { touchAlert.disarm() }
            case .touch:
                if coordinator.isActive { coordinator.stop() }
            }
            startError = nil
        }
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
        .sheet(isPresented: $showCalibration, onDismiss: { calibrator.cancel() }, content: {
            ClapCalibrationSheet(
                calibrator: calibrator,
                onCalibrated: { threshold in
                    catalogStore.calibratedClapCrest = threshold
                    showCalibration = false
                },
                onReset: {
                    catalogStore.calibratedClapCrest = nil
                    showCalibration = false
                }
            )
        })
    }

    // MARK: Sections

    private var headerSection: some View {
        VStack(spacing: CFSpacing.xs) {
            Text(NSLocalizedString("home.title", comment: "")) // allow-hardcoded-string until: pr-8
                .font(CFFont.display())
                .foregroundStyle(CFColor.textPrimary)

            Text(NSLocalizedString("home.subtitle", comment: "")) // allow-hardcoded-string until: pr-8
                .font(CFFont.callout())
                .foregroundStyle(CFColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var heroSection: some View {
        switch mode {
        case .clap:
            ZStack {
                // Pulse rings behind the toggle
                PulseRingsView(isActive: coordinator.isActive, diameter: 72)

                ListeningToggleView(isListening: coordinator.isActive) {
                    toggleListening()
                }
            }
            .frame(height: 180)

        case .touch:
            TouchAlertHeroView(
                state: touchAlert.state,
                graceRemaining: touchAlert.graceRemaining,
                gracePeriod: 5.0,
                onTap: toggleTouchAlert
            )
        }
    }

    private var statusLabel: some View {
        Group {
            if mode == .touch {
                touchStatusLabel
            } else if showFoundState {
                Text(NSLocalizedString("status.found", comment: "")) // allow-hardcoded-string until: pr-8
                    .foregroundStyle(CFColor.celebrationCyan)
            } else if coordinator.isActive {
                HStack(spacing: CFSpacing.xs) {
                    Circle()
                        .fill(CFColor.listeningActive)
                        .frame(width: 8, height: 8)
                    Text(NSLocalizedString("status.listening", comment: "")) // allow-hardcoded-string until: pr-8
                        .foregroundStyle(CFColor.listeningActive)
                }
            } else {
                Text(NSLocalizedString("status.idle", comment: "")) // allow-hardcoded-string until: pr-8
                    .foregroundStyle(CFColor.textTertiary)
            }
        }
        .font(CFFont.callout())
        .animation(.easeInOut(duration: 0.25), value: coordinator.isActive)
        .animation(.easeInOut(duration: 0.25), value: showFoundState)
    }

    @ViewBuilder
    private var touchStatusLabel: some View {
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

    private var animalSection: some View {
        @Bindable var store = catalogStore

        return VStack(alignment: .leading, spacing: CFSpacing.md) {
            Text(NSLocalizedString("animals.header", comment: "")) // allow-hardcoded-string until: pr-8
                .font(CFFont.headline())
                .foregroundStyle(CFColor.textPrimary)

            LazyVGrid(columns: gridColumns, spacing: CFSpacing.sm) {
                ForEach(catalogStore.animals) { animal in
                    AnimalCardView(
                        animal: animal,
                        isSelected: catalogStore.selectedAnimalID == animal.id
                    ) {
                        selectAnimal(animal)
                    }
                }
            }
        }
    }

    private var sensitivitySection: some View {
        @Bindable var store = catalogStore
        return SensitivityControlView(sensitivity: $store.sensitivity)
    }

    private var calibrateSection: some View {
        VStack(spacing: CFSpacing.xs) {
            Button {
                calibrator.reset()
                showCalibration = true
            } label: {
                Label(
                    NSLocalizedString("calibrate.button", comment: ""),
                    systemImage: "hand.tap"
                )
                .font(CFFont.callout())
                .foregroundStyle(CFColor.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, CFSpacing.sm)
                .background(CFColor.surfaceCard, in: Capsule())
            }
            .disabled(coordinator.isActive)

            if catalogStore.calibratedClapCrest != nil {
                Text(NSLocalizedString("calibrate.active", comment: ""))
                    .font(CFFont.caption())
                    .foregroundStyle(CFColor.listeningActive)
            }
        }
    }

    // MARK: Actions

    private func toggleListening() {
        startError = nil
        if coordinator.isActive {
            coordinator.stop()
            // Interstitial attempt at stop-listening ONLY (ADS_DESIGN.md D1).
            // Detection is now off; the policy re-checks every flag anyway.
            interstitials.attemptPresentation(
                isDetectionActive: coordinator.isActive,
                isAlarmActive: touchAlert.state != .disarmed
            )
        } else {
            guard let animal = catalogStore.selectedAnimal else { return }
            do {
                try coordinator.start(
                    animal: animal,
                    sensitivity: catalogStore.sensitivity,
                    crestOverride: catalogStore.calibratedClapCrest
                )
                interstitials.recordUse()   // D1: a use = a listening session start
            } catch {
                startError = error.localizedDescription
            }
        }
    }

    private func toggleTouchAlert() {
        startError = nil
        if touchAlert.state == .disarmed {
            if hasSeenNotifExplainer {
                armTouchAlert()
            } else {
                showNotifExplainer = true
            }
        } else {
            touchAlert.disarm()
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

    private func selectAnimal(_ animal: Animal) {
        // If already listening, restart with the new animal
        if coordinator.isActive {
            coordinator.stop()
            catalogStore.selectedAnimalID = animal.id
            guard let selected = catalogStore.selectedAnimal else { return }
            do {
                try coordinator.start(animal: selected, sensitivity: catalogStore.sensitivity)
            } catch {
                startError = error.localizedDescription
            }
        } else {
            catalogStore.selectedAnimalID = animal.id
        }
    }
}
