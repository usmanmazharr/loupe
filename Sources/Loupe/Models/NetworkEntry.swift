import Foundation

// MARK: - Entry Status

public enum NetworkEntryStatus: String, Codable, Sendable {
    case pending, inProgress, completed, failed, cancelled

    public var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled: return true
        case .pending, .inProgress: return false
        }
    }
}

// MARK: - Content Type

public enum ContentType: Codable, Sendable {
    case json, xml, html, plainText
    case image(String)
    case pdf, multipart, graphQL, binary
    case unknown(String)

    public var displayName: String {
        switch self {
        case .json: return "JSON"
        case .xml: return "XML"
        case .html: return "HTML"
        case .plainText: return "Text"
        case .image(let s): return "Image (\(s))"
        case .pdf: return "PDF"
        case .multipart: return "Multipart"
        case .graphQL: return "GraphQL"
        case .binary: return "Binary"
        case .unknown(let s): return s
        }
    }

    static func parse(_ mimeType: String?) -> ContentType {
        guard let mime = mimeType?.lowercased() else { return .unknown("") }
        if mime.contains("json")       { return .json }
        if mime.contains("graphql")    { return .graphQL }
        if mime.contains("xml")        { return .xml }
        if mime.contains("html")       { return .html }
        if mime.contains("multipart")  { return .multipart }
        if mime.contains("pdf")        { return .pdf }
        if mime.contains("image/jpeg") || mime.contains("image/jpg") { return .image("jpeg") }
        if mime.contains("image/png")  { return .image("png") }
        if mime.contains("image/gif")  { return .image("gif") }
        if mime.contains("image/")     { return .image(mime.components(separatedBy: "/").last ?? "unknown") }
        if mime.contains("text/")      { return .plainText }
        if mime.contains("octet-stream") { return .binary }
        return .unknown(mime)
    }
}

// MARK: - NetworkEntry

/// Complete record of a single HTTP transaction (request + response).
public final class NetworkEntry: Identifiable, ObservableObject, Codable, @unchecked Sendable {

    // MARK: Identity
    public let id: UUID
    /// Secondary mutable id used when restoring from SQLite (SQLite assigns a new UUID on decode).
    var id2: UUID?
    public var effectiveID: UUID { id2 ?? id }

    public let sessionID: String

    // MARK: Request
    public let url: URL
    public let method: String
    public var requestHeaders: [String: String]
    public var requestBody: Data?
    public var requestContentType: ContentType
    public var queryParameters: [String: String]

    // MARK: Response
    public var responseHeaders: [String: String]
    public var responseBody: Data?
    public var responseContentType: ContentType
    public var statusCode: Int?
    public var responseSize: Int64

    // MARK: Metadata
    public var status: NetworkEntryStatus
    public var timing: TimingMetrics
    public var timingDetail: NetworkTimingDetail?
    public var error: NetworkError?
    public var retryCount: Int
    public var uploadProgress: Double
    public var downloadProgress: Double
    public var isMocked: Bool
    public var isPinned: Bool = false

    // MARK: Helpers
    public var host: String { url.host ?? "" }
    public var path: String { url.path }
    public var isSuccess: Bool { statusCode.map { (200..<300).contains($0) } ?? false }
    public var curlCommand: String { CURLGenerator.generate(from: self) }

    // MARK: Init
    public init(
        url: URL,
        method: String,
        requestHeaders: [String: String] = [:],
        requestBody: Data? = nil,
        sessionID: String = UUID().uuidString,
        id: UUID = UUID()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.url = url
        self.method = method.uppercased()
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.requestContentType = ContentType.parse(requestHeaders["Content-Type"])
        self.queryParameters = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.reduce(into: [:]) { $0[$1.name] = $1.value ?? "" } ?? [:]
        self.responseHeaders = [:]
        self.responseContentType = .unknown("")
        self.responseSize = 0
        self.status = .pending
        self.timing = TimingMetrics()
        self.retryCount = 0
        self.uploadProgress = 0
        self.downloadProgress = 0
        self.isMocked = false
    }

    // MARK: Codable
    enum CodingKeys: String, CodingKey {
        case id, sessionID, url, method
        case requestHeaders, requestBody, requestContentType, queryParameters
        case responseHeaders, responseBody, responseContentType
        case statusCode, responseSize, status, timing, timingDetail
        case error, retryCount, uploadProgress, downloadProgress, isMocked, isPinned
    }

    public required init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(UUID.self,               forKey: .id)
        sessionID           = try c.decode(String.self,             forKey: .sessionID)
        url                 = try c.decode(URL.self,                forKey: .url)
        method              = try c.decode(String.self,             forKey: .method)
        requestHeaders      = try c.decode([String: String].self,   forKey: .requestHeaders)
        requestBody         = try c.decodeIfPresent(Data.self,      forKey: .requestBody)
        requestContentType  = try c.decode(ContentType.self,        forKey: .requestContentType)
        queryParameters     = try c.decode([String: String].self,   forKey: .queryParameters)
        responseHeaders     = try c.decode([String: String].self,   forKey: .responseHeaders)
        responseBody        = try c.decodeIfPresent(Data.self,      forKey: .responseBody)
        responseContentType = try c.decode(ContentType.self,        forKey: .responseContentType)
        statusCode          = try c.decodeIfPresent(Int.self,       forKey: .statusCode)
        responseSize        = try c.decode(Int64.self,              forKey: .responseSize)
        status              = try c.decode(NetworkEntryStatus.self, forKey: .status)
        timing              = try c.decode(TimingMetrics.self,      forKey: .timing)
        timingDetail        = try c.decodeIfPresent(NetworkTimingDetail.self, forKey: .timingDetail)
        error               = try c.decodeIfPresent(NetworkError.self, forKey: .error)
        retryCount          = try c.decode(Int.self,                forKey: .retryCount)
        uploadProgress      = try c.decode(Double.self,             forKey: .uploadProgress)
        downloadProgress    = try c.decode(Double.self,             forKey: .downloadProgress)
        isMocked            = try c.decodeIfPresent(Bool.self,      forKey: .isMocked) ?? false
        isPinned            = try c.decodeIfPresent(Bool.self,      forKey: .isPinned) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(effectiveID,         forKey: .id)
        try c.encode(sessionID,           forKey: .sessionID)
        try c.encode(url,                 forKey: .url)
        try c.encode(method,             forKey: .method)
        try c.encode(requestHeaders,      forKey: .requestHeaders)
        try c.encodeIfPresent(requestBody,  forKey: .requestBody)
        try c.encode(requestContentType,  forKey: .requestContentType)
        try c.encode(queryParameters,     forKey: .queryParameters)
        try c.encode(responseHeaders,     forKey: .responseHeaders)
        try c.encodeIfPresent(responseBody, forKey: .responseBody)
        try c.encode(responseContentType, forKey: .responseContentType)
        try c.encodeIfPresent(statusCode, forKey: .statusCode)
        try c.encode(responseSize,        forKey: .responseSize)
        try c.encode(status,             forKey: .status)
        try c.encode(timing,             forKey: .timing)
        try c.encodeIfPresent(timingDetail, forKey: .timingDetail)
        try c.encodeIfPresent(error,      forKey: .error)
        try c.encode(retryCount,          forKey: .retryCount)
        try c.encode(uploadProgress,      forKey: .uploadProgress)
        try c.encode(downloadProgress,    forKey: .downloadProgress)
        try c.encode(isMocked,           forKey: .isMocked)
        try c.encode(isPinned,           forKey: .isPinned)
    }
}

// MARK: - NetworkError

public struct NetworkError: Codable, Sendable {
    public let domain: String
    public let code: Int
    public let localizedDescription: String

    public init(error: Error) {
        let e = error as NSError
        self.domain = e.domain
        self.code = e.code
        self.localizedDescription = error.localizedDescription
    }

    init(domain: String, code: Int, localizedDescription: String) {
        self.domain = domain
        self.code = code
        self.localizedDescription = localizedDescription
    }
}
