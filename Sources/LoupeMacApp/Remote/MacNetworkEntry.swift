import Foundation

// MARK: - Status

enum MacEntryStatus: String, Codable {
    case pending, inProgress, completed, failed, cancelled

    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        case .pending, .inProgress:           return false
        }
    }
}

// MARK: - Content Type

enum MacContentType: Codable {
    case json, xml, html, plainText
    case image(String)
    case pdf, multipart, graphQL, binary
    case unknown(String)

    var displayName: String {
        switch self {
        case .json:           return "JSON"
        case .xml:            return "XML"
        case .html:           return "HTML"
        case .plainText:      return "Text"
        case .image(let s):   return "Image (\(s))"
        case .pdf:            return "PDF"
        case .multipart:      return "Multipart"
        case .graphQL:        return "GraphQL"
        case .binary:         return "Binary"
        case .unknown(let s): return s
        }
    }
}

// MARK: - Timing

struct MacTimingMetrics: Codable {
    let startDate: Date
    var endDate:   Date?

    var totalDuration: TimeInterval? { endDate.map { $0.timeIntervalSince(startDate) } }

    var formattedDuration: String {
        guard let d = totalDuration else { return "—" }
        return d < 1 ? String(format: "%.0f ms", d * 1_000) : String(format: "%.2f s", d)
    }

    // Tolerate partial timing objects from the wire.
    enum CodingKeys: String, CodingKey {
        case startDate, connectDate, firstByteDate, endDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        startDate = try c.decode(Date.self, forKey: .startDate)
        endDate   = try c.decodeIfPresent(Date.self, forKey: .endDate)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(startDate, forKey: .startDate)
        try c.encodeIfPresent(endDate, forKey: .endDate)
    }
}

// MARK: - Error

struct MacNetworkError: Codable {
    let domain:               String
    let code:                 Int
    let localizedDescription: String
}

// MARK: - Network Entry

/// Decodable mirror of the iOS `NetworkEntry` class.
/// CodingKeys must stay in sync with the iOS model.
struct MacNetworkEntry: Identifiable, Codable {

    let id:                  UUID
    let sessionID:           String
    let url:                 URL
    let method:              String
    var requestHeaders:      [String: String]
    var requestBody:         Data?
    var requestContentType:  MacContentType
    var queryParameters:     [String: String]
    var responseHeaders:     [String: String]
    var responseBody:        Data?
    var responseContentType: MacContentType
    var statusCode:          Int?
    var responseSize:        Int64
    var status:              MacEntryStatus
    var timing:              MacTimingMetrics
    var error:               MacNetworkError?
    var retryCount:          Int
    var uploadProgress:      Double
    var downloadProgress:    Double
    var isMocked:            Bool
    var isPinned:            Bool

    var host:      String { url.host ?? "" }
    var path:      String { url.path.isEmpty ? "/" : url.path }
    var isSuccess: Bool   { statusCode.map { (200 ..< 300).contains($0) } ?? false }

    // MARK: cURL

    var curlCommand: String {
        var parts: [String] = ["curl"]
        if method != "GET" { parts += ["-X", method] }
        for (k, v) in requestHeaders.sorted(by: { $0.key < $1.key }) {
            parts += ["-H", "\"\(k): \(v)\""]
        }
        if let body = requestBody, !body.isEmpty {
            if let text = String(data: body, encoding: .utf8) {
                let escaped = text.replacingOccurrences(of: "'", with: "'\\''")
                parts += ["--data-raw", "'\(escaped)'"]
            }
        }
        parts.append("\"\(url.absoluteString)\"")
        return parts.joined(separator: " \\\n  ")
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, sessionID, url, method
        case requestHeaders, requestBody, requestContentType, queryParameters
        case responseHeaders, responseBody, responseContentType
        case statusCode, responseSize, status, timing
        case error, retryCount, uploadProgress, downloadProgress, isMocked, isPinned
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(UUID.self,                  forKey: .id)
        sessionID            = try c.decode(String.self,                forKey: .sessionID)
        url                  = try c.decode(URL.self,                   forKey: .url)
        method               = try c.decode(String.self,                forKey: .method)
        requestHeaders       = try c.decode([String: String].self,      forKey: .requestHeaders)
        requestBody          = try c.decodeIfPresent(Data.self,         forKey: .requestBody)
        requestContentType   = try c.decode(MacContentType.self,        forKey: .requestContentType)
        queryParameters      = try c.decode([String: String].self,      forKey: .queryParameters)
        responseHeaders      = try c.decode([String: String].self,      forKey: .responseHeaders)
        responseBody         = try c.decodeIfPresent(Data.self,         forKey: .responseBody)
        responseContentType  = try c.decode(MacContentType.self,        forKey: .responseContentType)
        statusCode           = try c.decodeIfPresent(Int.self,          forKey: .statusCode)
        responseSize         = try c.decode(Int64.self,                 forKey: .responseSize)
        status               = try c.decode(MacEntryStatus.self,        forKey: .status)
        timing               = try c.decode(MacTimingMetrics.self,      forKey: .timing)
        error                = try c.decodeIfPresent(MacNetworkError.self, forKey: .error)
        retryCount           = try c.decode(Int.self,                   forKey: .retryCount)
        uploadProgress       = try c.decode(Double.self,                forKey: .uploadProgress)
        downloadProgress     = try c.decode(Double.self,                forKey: .downloadProgress)
        isMocked             = try c.decode(Bool.self,                  forKey: .isMocked)
        isPinned             = try c.decodeIfPresent(Bool.self,         forKey: .isPinned) ?? false
    }
}

// MARK: - Device Info (mirror of iOS DeviceInfo)

struct MacDeviceInfo: Codable {
    let deviceName: String
    let appName:    String
    let appVersion: String
    let bundleID:   String
}

// MARK: - Wire Envelope (mirror of iOS RemoteEnvelope)

struct MacRemoteEnvelope: Codable {
    enum MessageType: String, Codable {
        case hello, batch, entry, clear, requestClear
        case logMessage, logBatch
        case analyticsEvent, analyticsBatch
        case setPinned
    }
    let type:    MessageType
    let payload: Data?
}

// MARK: - LogMessage (mirror of iOS LogMessage)

struct MacLogMessage: Identifiable, Codable, Equatable {
    enum Level: String, Codable, CaseIterable {
        case trace, debug, info, notice, warning, error, fault
        var displayName: String { rawValue.capitalized }
    }
    let id: UUID
    let timestamp: Date
    let level: Level
    let subsystem: String
    let category: String
    let message: String
}

// MARK: - AnalyticsEvent (mirror of iOS AnalyticsEvent)

struct MacAnalyticsEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let timestamp: Date
    let provider: String
    let name: String
    let properties: [String: String]
    let screen: String?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, provider, name, properties, screen
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self,             forKey: .id)
        timestamp  = try c.decode(Date.self,             forKey: .timestamp)
        provider   = try c.decode(String.self,           forKey: .provider)
        name       = try c.decode(String.self,           forKey: .name)
        properties = try c.decode([String: String].self, forKey: .properties)
        screen     = try c.decodeIfPresent(String.self,  forKey: .screen)
    }

    var propertiesPreview: String {
        properties
            .sorted { $0.key < $1.key }
            .prefix(4)
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " · ")
    }
}

// MARK: - Set-pinned payload (mirror of iOS SetPinnedPayload)

struct MacSetPinnedPayload: Codable {
    let id: UUID
    let pinned: Bool
}

// MARK: - Data helpers

extension Int64 {
    var macFormattedSize: String {
        let d = Double(self)
        if d < 1_024             { return "\(Int(d)) B" }
        if d < 1_024 * 1_024     { return String(format: "%.1f KB", d / 1_024) }
        return String(format: "%.1f MB", d / (1_024 * 1_024))
    }
}
