import Foundation

/// A single rule that the MockEngine checks against every outgoing request.
public struct MockRule: Identifiable, Codable, Sendable {

    public var id: UUID
    public var isEnabled: Bool
    public var name: String

    /// Supports: exact URL, URL substring, wildcard (`/api/v1/*`), or regex.
    public var urlPattern: String

    /// `nil` matches any HTTP method.
    public var method: String?

    public var statusCode: Int
    public var responseBody: Data?
    public var responseHeaders: [String: String]

    /// Artificial delay before the mock response is delivered.
    public var delay: TimeInterval

    /// When set, the interceptor returns a `URLError` instead of an HTTP response.
    public var errorCode: URLError.Code?

    // MARK: - Init

    public init(
        id: UUID = UUID(),
        isEnabled: Bool = true,
        name: String,
        urlPattern: String,
        method: String? = nil,
        statusCode: Int = 200,
        responseBody: Data? = nil,
        responseHeaders: [String: String] = ["Content-Type": "application/json"],
        delay: TimeInterval = 0,
        errorCode: URLError.Code? = nil
    ) {
        self.id              = id
        self.isEnabled       = isEnabled
        self.name            = name
        self.urlPattern      = urlPattern
        self.method          = method
        self.statusCode      = statusCode
        self.responseBody    = responseBody
        self.responseHeaders = responseHeaders
        self.delay           = delay
        self.errorCode       = errorCode
    }

    // MARK: - Matching

    /// Returns `true` when this rule should intercept `request`.
    func matches(_ request: URLRequest) -> Bool {
        guard isEnabled else { return false }
        if let method, let httpMethod = request.httpMethod {
            guard method.uppercased() == httpMethod.uppercased() else { return false }
        }
        guard let urlString = request.url?.absoluteString else { return false }
        return urlMatches(urlString)
    }

    private func urlMatches(_ url: String) -> Bool {
        // Exact
        if url == urlPattern { return true }

        // Wildcard: convert `/api/*` → regex `^.*\/api\/.*$`
        if urlPattern.contains("*") {
            let escaped  = NSRegularExpression.escapedPattern(for: urlPattern)
            let regexStr = "^" + escaped.replacingOccurrences(of: "\\*", with: ".*") + "$"
            if let re = try? NSRegularExpression(pattern: regexStr),
               re.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil {
                return true
            }
        }

        // Substring
        if url.contains(urlPattern) { return true }

        // Raw regex
        if let re = try? NSRegularExpression(pattern: urlPattern),
           re.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil {
            return true
        }

        return false
    }
}

// MARK: - URLError.Code Codable

extension URLError.Code: Codable {
    public init(from decoder: Decoder) throws {
        let rawValue = try decoder.singleValueContainer().decode(Int.self)
        self = URLError.Code(rawValue: rawValue)
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}
