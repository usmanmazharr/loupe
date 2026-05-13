import Foundation

/// Masks sensitive values in headers and JSON bodies according to the active configuration.
public final class SecurityManager: @unchecked Sendable {

    private let configuration: LoupeConfiguration
    private let lock = NSLock()

    public init(configuration: LoupeConfiguration) {
        self.configuration = configuration
    }

    // MARK: - Header masking

    /// Returns a copy of `headers` with sensitive values replaced by the masking string.
    public func sanitize(headers: [String: String]) -> [String: String] {
        headers.reduce(into: [:]) { result, pair in
            let isSecret = configuration.sensitiveHeaders.contains(where: {
                $0.lowercased() == pair.key.lowercased()
            })
            result[pair.key] = isSecret ? configuration.maskingString : pair.value
        }
    }

    // MARK: - Body masking

    /// Returns a copy of `body` (re-serialized JSON) with sensitive key values masked.
    /// Non-JSON data is returned unchanged.
    public func sanitize(body: Data?) -> Data? {
        guard let body, !body.isEmpty else { return body }
        guard let obj = try? JSONSerialization.jsonObject(with: body) else { return body }
        let sanitized = mask(value: obj)
        return (try? JSONSerialization.data(withJSONObject: sanitized, options: .prettyPrinted)) ?? body
    }

    // MARK: - URL masking

    /// Removes sensitive query parameter values from a URL.
    public func sanitize(url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.queryItems = components.queryItems?.map { item in
            let isSensitive = configuration.sensitiveBodyKeys.contains(where: {
                $0.lowercased() == item.name.lowercased()
            })
            return isSensitive ? URLQueryItem(name: item.name, value: configuration.maskingString) : item
        }
        return components.url ?? url
    }

    // MARK: - Private

    private func mask(value: Any) -> Any {
        if let dict = value as? [String: Any] {
            return dict.reduce(into: [String: Any]()) { result, pair in
                let isSensitive = configuration.sensitiveBodyKeys.contains(where: {
                    $0.lowercased() == pair.key.lowercased()
                })
                result[pair.key] = isSensitive ? configuration.maskingString : mask(value: pair.value)
            }
        }
        if let array = value as? [Any] {
            return array.map { mask(value: $0) }
        }
        return value
    }
}
