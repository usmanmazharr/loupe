import Foundation
import UIKit

// MARK: - Wire Envelope

/// Outer frame for every message sent over the TCP connection.
struct RemoteEnvelope: Codable {

    enum MessageType: String, Codable {
        /// Initial handshake — payload is DeviceInfo.
        case hello
        /// Full snapshot sent to a freshly connected client — payload is [NetworkEntry].
        case batch
        /// Single new or updated entry — payload is NetworkEntry.
        case entry
        /// Logs were cleared on the iOS side — no payload.
        case clear
        /// macOS → iOS: request the iOS side to wipe its log store.
        case requestClear
        /// Single console log line — payload is LogMessage.
        case logMessage
        /// Batch of recent console log lines — payload is [LogMessage].
        case logBatch
        /// Single analytics event — payload is AnalyticsEvent.
        case analyticsEvent
        /// Batch of recent analytics events — payload is [AnalyticsEvent].
        case analyticsBatch
        /// macOS → iOS: toggle the pinned flag for an entry.
        /// Payload is { "id": UUID-string, "pinned": Bool }.
        case setPinned
    }

    let type: MessageType
    /// JSON-encoded payload; nil for messages that carry no data.
    let payload: Data?

    init(type: MessageType, payload: Data? = nil) {
        self.type    = type
        self.payload = payload
    }
}

// MARK: - Device Info

/// Payload for the `setPinned` message.
struct SetPinnedPayload: Codable {
    let id: UUID
    let pinned: Bool
}

/// Metadata about the connected iOS device, sent during the hello handshake.
public struct DeviceInfo: Codable, Sendable {
    public let deviceName: String
    public let appName:    String
    public let appVersion: String
    public let bundleID:   String

    public init() {
        deviceName = UIDevice.current.name
        appName    = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
                   ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
                   ?? "Unknown App"
        appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        bundleID   = Bundle.main.bundleIdentifier ?? "unknown"
    }
}
