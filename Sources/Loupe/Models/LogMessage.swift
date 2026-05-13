import Foundation

/// A single in-app log line captured by Loupe, separate from network
/// entries. Mirrors what `print()`, `os_log`, or `Logger` produces.
public struct LogMessage: Identifiable, Codable, Equatable, Sendable {

    public enum Level: String, Codable, Sendable, CaseIterable {
        case trace, debug, info, notice, warning, error, fault

        public var displayName: String { rawValue.capitalized }

        /// Sort order for filter pills.
        public var rank: Int {
            switch self {
            case .trace:   return 0
            case .debug:   return 1
            case .info:    return 2
            case .notice:  return 3
            case .warning: return 4
            case .error:   return 5
            case .fault:   return 6
            }
        }
    }

    public let id: UUID
    public let timestamp: Date
    public let level: Level
    public let subsystem: String
    public let category: String
    public let message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: Level,
        subsystem: String = "",
        category: String = "",
        message: String
    ) {
        self.id        = id
        self.timestamp = timestamp
        self.level     = level
        self.subsystem = subsystem
        self.category  = category
        self.message   = message
    }
}
