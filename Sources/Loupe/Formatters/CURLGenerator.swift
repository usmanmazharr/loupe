import Foundation

/// Generates a runnable `curl` command from a `NetworkEntry`.
public enum CURLGenerator {

    public static func generate(from entry: NetworkEntry) -> String {
        var components: [String] = ["curl"]

        // Method (skip -X GET to keep the default)
        if entry.method != "GET" {
            components += ["-X", entry.method]
        }

        // Headers
        for (key, value) in entry.requestHeaders.sorted(by: { $0.key < $1.key }) {
            components += ["-H", "\"\(key): \(value)\""]
        }

        // Body
        if let body = entry.requestBody, !body.isEmpty {
            if let text = String(data: body, encoding: .utf8), !text.isEmpty {
                let escaped = text.replacingOccurrences(of: "'", with: "'\\''")
                components += ["--data-raw", "'\(escaped)'"]
            } else {
                // Binary body – use base64
                let b64 = body.base64EncodedString()
                components += ["--data-binary", "@<(echo \(b64) | base64 --decode)"]
            }
        }

        // URL (always last)
        components.append("\"\(entry.url.absoluteString)\"")

        return components.joined(separator: " \\\n  ")
    }
}
