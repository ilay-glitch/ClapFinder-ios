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

    @State private var startError: String?
    /// Pre-permission explainer before the first arm (design §4.2 ruling).
    @AppStorage("touchAlert.hasSeenNotifExplainer") private var hasSeenNotifExplainer = false
    @State private var showNotifExplainer = false

    private let gridColumns = Array(repeating: GridItem(.fixed(80), spacing: CFSpacing.sm), count: 4)

    var body: some View {
        ZStack {
            CFColor.skyPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, CFSpacing.lg)

                    TouchAlertHeroView(
                        state: touchAlert.state,
                        graceRemaining: touchAlert.graceRemaining,
                        gracePeriod: 5.0,
                        onTap: toggleTouchAlert
                    )
                    .padding(.top, CFSpacing.lg)

                    statusLabel
                        .padding(.top, CFSpacing.md)

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

    /// Persists the guard choice. While armed, monitoring continues with the
    /// sound it was armed with; the new choice takes effect on the next arm.
    private func selectGuard(_ animal: Animal) {
        catalogStore.selectedAnimalID = animal.id
    }
}
