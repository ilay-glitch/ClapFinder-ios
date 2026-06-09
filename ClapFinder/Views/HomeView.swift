import ClapFinderKitAudio
import ClapFinderKitData
import ClapFinderKitDesign
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

    /// Tracks the brief "Found you!" flash after a clap is detected.
    @State private var showFoundState = false
    @State private var startError: String?

    private let gridColumns = Array(repeating: GridItem(.fixed(80), spacing: CFSpacing.sm), count: 4)

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────
            CFColor.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                        .padding(.top, CFSpacing.lg)

                    heroSection
                        .padding(.top, CFSpacing.xl)

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
                        .padding(.bottom, CFSpacing.xxl)
                }
                .padding(.horizontal, CFSpacing.md)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: coordinator.lastTriggeredAnimal) { _, animal in
            guard animal != nil else { return }
            showFoundState = true
            Task {
                try? await Task.sleep(for: .seconds(2.0))
                showFoundState = false
            }
        }
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

    private var heroSection: some View {
        ZStack {
            // Pulse rings behind the toggle
            PulseRingsView(isActive: coordinator.isActive, diameter: 72)

            ListeningToggleView(isListening: coordinator.isActive) {
                toggleListening()
            }
        }
        .frame(height: 180)
    }

    private var statusLabel: some View {
        Group {
            if showFoundState {
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

    // MARK: Actions

    private func toggleListening() {
        startError = nil
        if coordinator.isActive {
            coordinator.stop()
        } else {
            guard let animal = catalogStore.selectedAnimal else { return }
            do {
                try coordinator.start(animal: animal, sensitivity: catalogStore.sensitivity)
            } catch {
                startError = error.localizedDescription
            }
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
