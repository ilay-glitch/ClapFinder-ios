import Foundation

// MARK: - Animal

/// A single entry from the animal sound catalog.
public struct Animal: Codable, Identifiable, Equatable, Sendable {
    /// Stable string key — matches the `id` field in catalog.json.
    public let id: String
    /// Localised display name, e.g. "Dog".
    public let name: String
    /// Single emoji representing the animal, e.g. "🐕".
    public let emoji: String
    /// Filename of the bundled CAF audio resource, e.g. "dog_bark.caf".
    public let soundFile: String

    public init(id: String, name: String, emoji: String, soundFile: String) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.soundFile = soundFile
    }
}
