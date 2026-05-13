import Foundation

extension URLRequest {

    /// Lowercased key → value dictionary of all HTTP headers.
    var normalizedHeaders: [String: String] {
        allHTTPHeaderFields?.reduce(into: [:]) { $0[$1.key] = $1.value } ?? [:]
    }

    /// Content-Type header value.
    var contentType: String? {
        allHTTPHeaderFields?
            .first(where: { $0.key.lowercased() == "content-type" })?
            .value
    }
}

extension URLResponse {

    /// HTTP status code from `HTTPURLResponse`, or nil.
    var httpStatusCode: Int? {
        (self as? HTTPURLResponse)?.statusCode
    }

    /// All response headers as `[String: String]`.
    var allHeaders: [String: String] {
        (self as? HTTPURLResponse)?.allHeaderFields
            .reduce(into: [:]) { result, pair in
                if let key = pair.key as? String {
                    result[key] = pair.value as? String ?? String(describing: pair.value)
                }
            } ?? [:]
    }

    /// Content-Type from response headers.
    var contentMimeType: String? {
        (self as? HTTPURLResponse)?.allHeaderFields
            .first(where: { ($0.key as? String)?.lowercased() == "content-type" })?
            .value as? String
    }
}
