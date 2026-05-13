import Foundation

extension Int64 {
    var formattedSize: String { Double(self).formattedBytes }
}

extension Int {
    var formattedSize: String { Double(self).formattedBytes }
}

private extension Double {
    var formattedBytes: String {
        if self < 1_024 { return "\(Int(self)) B" }
        if self < 1_024 * 1_024 { return String(format: "%.1f KB", self / 1_024) }
        return String(format: "%.1f MB", self / (1_024 * 1_024))
    }
}

extension Data {

    /// Returns a human-readable file size string (e.g. "1.2 MB").
    var formattedSize: String { count.formattedSize }

    /// Returns `true` when the data starts with a known binary magic number.
    var isBinary: Bool {
        guard count > 4 else { return false }
        let header = prefix(4).map { $0 }
        // PDF
        if header.starts(with: [0x25, 0x50, 0x44, 0x46]) { return true }
        // PNG
        if header.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return true }
        // JPEG
        if header.starts(with: [0xFF, 0xD8, 0xFF]) { return true }
        // GIF
        if header.starts(with: [0x47, 0x49, 0x46, 0x38]) { return true }
        // ZIP/IPA
        if header.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return true }
        // Check for high concentration of non-UTF8 bytes
        let sample = prefix(512)
        let nonPrintable = sample.filter { $0 < 0x09 || ($0 > 0x0D && $0 < 0x20) }
        return Double(nonPrintable.count) / Double(sample.count) > 0.1
    }

    /// Attempts to decode as UTF-8 string.
    var utf8String: String? {
        String(data: self, encoding: .utf8)
    }

    /// Pretty-prints JSON data; returns nil if not valid JSON.
    var prettyPrintedJSON: String? {
        guard let obj = try? JSONSerialization.jsonObject(with: self),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8) else { return nil }
        return str
    }
}
