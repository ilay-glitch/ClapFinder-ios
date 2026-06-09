import Foundation
import Observation

// MARK: - CatalogStore

/// Observable store that owns the animal catalog and user preferences.
///
/// Loaded once at app start; preferences (`selectedAnimalID`, `sensitivity`)
/// are persisted to `UserDefaults` immediately on change.
@Observable
@MainActor
public final class CatalogStore {

    // MARK: Public state

    /// All animals from catalog.json, in catalog order.
    public private(set) var animals: [Animal] = []

    /// The ID of the currently selected animal. Defaults to "dog".
    public var selectedAnimalID: String {
        didSet { defaults.set(selectedAnimalID, forKey: Keys.selectedAnimalID) }
    }

    /// Clap-detection sensitivity. Defaults to `.medium`.
    public var sensitivity: Sensitivity {
        didSet { defaults.set(sensitivity.rawValue, forKey: Keys.sensitivity) }
    }

    // MARK: Derived

    /// The currently selected `Animal`, or `nil` if the catalog is empty.
    public var selectedAnimal: Animal? {
        animals.first { $0.id == selectedAnimalID }
    }

    // MARK: Private

    private let defaults: UserDefaults

    // MARK: UserDefaults keys

    private enum Keys {
        static let selectedAnimalID = "cf_selectedAnimalID"
        static let sensitivity      = "cf_sensitivity"
    }

    // MARK: Init

    /// - Parameter defaults: Defaults store to use. Pass `.standard` in production;
    ///   inject a custom suite in tests to avoid polluting the real store.
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        // Restore persisted preferences (fallback to safe defaults).
        let storedID = defaults.string(forKey: Keys.selectedAnimalID) ?? "dog"
        let storedSensRaw = defaults.string(forKey: Keys.sensitivity) ?? ""
        let storedSens = Sensitivity(rawValue: storedSensRaw) ?? .medium

        self.selectedAnimalID = storedID
        self.sensitivity = storedSens

        loadCatalog()
    }

    // MARK: Catalog loading

    private func loadCatalog() {
        guard
            let url = Bundle.module.url(forResource: "catalog", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([Animal].self, from: data)
        else {
            assertionFailure("CatalogStore: failed to load catalog.json from bundle")
            return
        }
        animals = decoded

        // If the persisted ID no longer exists in the catalog, reset to first animal.
        if selectedAnimal == nil, let first = animals.first {
            selectedAnimalID = first.id
        }
    }
}
