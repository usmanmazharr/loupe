import Foundation

extension String {

    /// Truncates string to `length` characters, appending `…` if truncated.
    func truncated(to length: Int) -> String {
        guard count > length else { return self }
        return String(prefix(length)) + "…"
    }

    /// Encodes the string for safe use in a shell argument.
    var shellEscaped: String {
        "'" + replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Returns `true` when the string looks like valid JSON.
    var isJSON: Bool {
        guard let data = data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    /// Returns `true` when the string looks like XML.
    var isXML: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<")
    }
}
