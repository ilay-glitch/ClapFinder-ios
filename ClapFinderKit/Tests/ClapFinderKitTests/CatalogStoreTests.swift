#if canImport(Testing)
import Testing
import Foundation
@testable import ClapFinderKitData

// MARK: - CatalogStore Tests

@MainActor
struct CatalogStoreTests {

    // MARK: Catalog loading

    @Test("Catalog loads all 16 sounds")
    func catalogLoads16Sounds() {
        let store = CatalogStore(defaults: makeTestDefaults())
        #expect(store.animals.count == 16)
    }

    @Test("Catalog ids are all unique")
    func catalogIDsUnique() {
        let store = CatalogStore(defaults: makeTestDefaults())
        let ids = store.animals.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Catalog animals all have non-empty fields")
    func catalogAnimalsHaveNonEmptyFields() {
        let store = CatalogStore(defaults: makeTestDefaults())
        for animal in store.animals {
            #expect(!animal.id.isEmpty)
            #expect(!animal.name.isEmpty)
            #expect(!animal.emoji.isEmpty)
            #expect(!animal.soundFile.isEmpty)
        }
    }

    @Test("First animal is dog")
    func firstAnimalIsDog() {
        let store = CatalogStore(defaults: makeTestDefaults())
        #expect(store.animals.first?.id == "dog")
    }

    @Test("All sound files have .caf extension")
    func soundFilesHaveCafExtension() {
        let store = CatalogStore(defaults: makeTestDefaults())
        for animal in store.animals {
            #expect(animal.soundFile.hasSuffix(".caf"),
                    "Expected .caf extension for \(animal.id)")
        }
    }

    // MARK: Default selection

    @Test("Default selected sound is siren when no persisted value")
    func defaultSelectedSoundIsSiren() {
        let store = CatalogStore(defaults: makeTestDefaults())
        #expect(store.selectedAnimalID == "siren")
        #expect(store.selectedAnimal?.id == "siren", "default must resolve to a real catalog entry")
    }

    @Test("selectedAnimal returns the correct Animal for the stored ID")
    func selectedAnimalMatchesID() {
        let store = CatalogStore(defaults: makeTestDefaults())
        store.selectedAnimalID = "cat"
        #expect(store.selectedAnimal?.id == "cat")
    }

    // MARK: Persistence

    @Test("Changing selectedAnimalID persists to UserDefaults")
    func selectedAnimalIDPersists() {
        let defaults = makeTestDefaults()
        let store = CatalogStore(defaults: defaults)
        store.selectedAnimalID = "bell"
        #expect(defaults.string(forKey: "cf_selectedAnimalID") == "bell")
    }

    @Test("Changing sensitivity persists to UserDefaults")
    func sensitivityPersists() {
        let defaults = makeTestDefaults()
        let store = CatalogStore(defaults: defaults)
        store.sensitivity = .high
        #expect(defaults.string(forKey: "cf_sensitivity") == "high")
    }

    @Test("Store restores persisted selectedAnimalID on re-init")
    func storeRestoresPersistedAnimalID() {
        let defaults = makeTestDefaults()
        let storeA = CatalogStore(defaults: defaults)
        storeA.selectedAnimalID = "foghorn"

        let storeB = CatalogStore(defaults: defaults)
        #expect(storeB.selectedAnimalID == "foghorn")
    }

    @Test("Store restores persisted sensitivity on re-init")
    func storeRestoresPersistedSensitivity() {
        let defaults = makeTestDefaults()
        let storeA = CatalogStore(defaults: defaults)
        storeA.sensitivity = .low

        let storeB = CatalogStore(defaults: defaults)
        #expect(storeB.sensitivity == .low)
    }

    @Test("Unknown persisted ID resets to first animal")
    func unknownPersistedIDResetsToFirst() {
        let defaults = makeTestDefaults()
        defaults.set("unicorn", forKey: "cf_selectedAnimalID")
        let store = CatalogStore(defaults: defaults)
        #expect(store.selectedAnimalID == store.animals.first?.id)
    }

    // MARK: Default sensitivity

    @Test("Default sensitivity is medium when no persisted value")
    func defaultSensitivityIsMedium() {
        let store = CatalogStore(defaults: makeTestDefaults())
        #expect(store.sensitivity == .medium)
    }
}

// MARK: - Sensitivity Tests

struct SensitivityTests {

    @Test("Low threshold is -30 dBFS")
    func lowThreshold() {
        #expect(Sensitivity.low.threshold == -30.0)
    }

    @Test("Medium threshold is -40 dBFS")
    func mediumThreshold() {
        #expect(Sensitivity.medium.threshold == -40.0)
    }

    @Test("High threshold is -50 dBFS")
    func highThreshold() {
        #expect(Sensitivity.high.threshold == -50.0)
    }

    @Test("Clap confidence threshold: Low strictest, High most forgiving")
    func clapConfidenceThresholds() {
        #expect(Sensitivity.low.clapConfidenceThreshold == 0.75)
        #expect(Sensitivity.medium.clapConfidenceThreshold == 0.55)
        #expect(Sensitivity.high.clapConfidenceThreshold == 0.40)
        // Higher sensitivity must require *less* confidence (more forgiving).
        #expect(Sensitivity.high.clapConfidenceThreshold < Sensitivity.medium.clapConfidenceThreshold)
        #expect(Sensitivity.medium.clapConfidenceThreshold < Sensitivity.low.clapConfidenceThreshold)
    }

    @Test("All cases have non-empty display names")
    func allCasesHaveDisplayNames() {
        for s in Sensitivity.allCases {
            #expect(!s.displayName.isEmpty)
        }
    }

    @Test("Sensitivity is Codable round-trip")
    func sensitivityCodableRoundTrip() throws {
        for s in Sensitivity.allCases {
            let data = try JSONEncoder().encode(s)
            let decoded = try JSONDecoder().decode(Sensitivity.self, from: data)
            #expect(decoded == s)
        }
    }
}

// MARK: - Animal Tests

struct AnimalTests {

    @Test("Animal is Codable round-trip")
    func animalCodableRoundTrip() throws {
        let animal = Animal(id: "dog", name: "Dog", emoji: "🐕", soundFile: "dog_bark.caf")
        let data = try JSONEncoder().encode(animal)
        let decoded = try JSONDecoder().decode(Animal.self, from: data)
        #expect(decoded == animal)
    }

    @Test("Animal Identifiable id matches stored id")
    func animalIdentifiableID() {
        let animal = Animal(id: "cat", name: "Cat", emoji: "🐈", soundFile: "cat_meow.caf")
        #expect(animal.id == "cat")
    }
}

// MARK: - Helpers

/// Creates an isolated in-memory UserDefaults suite so tests don't touch .standard.
@MainActor
private func makeTestDefaults() -> UserDefaults {
    let suiteName = "com.appcentral.clapfinder.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
#endif
