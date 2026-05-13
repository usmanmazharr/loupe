import Foundation

/// A single analytics event captured by Loupe — Mixpanel, Firebase,
/// Adjust, Insider, Segment, or anything else the host app reports via
/// `Loupe.shared.trackEvent(...)`.
public struct AnalyticsEvent: Identifiable, Codable, Equatable, Sendable {

    public let id: UUID
    public let timestamp: Date
    /// Human-readable source name: "Mixpanel", "Firebase", "Adjust", "Insider", "Segment", "Custom"…
    public let provider: String
    /// Event name as the SDK was given it.
    public let name: String
    /// Flat string-keyed properties. The host app stringifies anything non-trivial.
    public let properties: [String: String]
    /// Screen / view the event was fired from. Auto-filled from the current
    /// screen registered via `Loupe.shared.setCurrentScreen(_:)`, or supplied
    /// explicitly by the caller. `nil` means "unknown".
    public let screen: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        provider: String,
        name: String,
        properties: [String: String] = [:],
        screen: String? = nil
    ) {
        self.id         = id
        self.timestamp  = timestamp
        self.provider   = provider
        self.name       = name
        self.properties = properties
        self.screen     = screen
    }

    enum CodingKeys: String, CodingKey {
        case id, timestamp, provider, name, properties, screen
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self,                forKey: .id)
        timestamp  = try c.decode(Date.self,                forKey: .timestamp)
        provider   = try c.decode(String.self,              forKey: .provider)
        name       = try c.decode(String.self,              forKey: .name)
        properties = try c.decode([String: String].self,    forKey: .properties)
        screen     = try c.decodeIfPresent(String.self,     forKey: .screen)
    }

    /// One-line summary for list rows: `key=value · key2=value2`.
    public var propertiesPreview: String {
        properties
            .sorted { $0.key < $1.key }
            .prefix(4)
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " · ")
    }
}
