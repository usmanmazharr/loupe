import UIKit

/// Builds exportable representations of log entries and presents a share sheet.
public enum ExportManager {

    // MARK: - Export Format

    public enum Format {
        case json
        case plainText
        case curl
        case har   // HTTP Archive format
    }

    // MARK: - Export single entry

    public static func export(entry: NetworkEntry, format: Format) -> String {
        switch format {
        case .json:
            return exportJSON([entry])
        case .plainText:
            return exportText(entry)
        case .curl:
            return CURLGenerator.generate(from: entry)
        case .har:
            return exportHAR([entry])
        }
    }

    // MARK: - Export all entries

    public static func export(entries: [NetworkEntry], format: Format) -> String {
        switch format {
        case .json:
            return exportJSON(entries)
        case .plainText:
            return entries.map { exportText($0) }.joined(separator: "\n\n---\n\n")
        case .curl:
            return entries.map { CURLGenerator.generate(from: $0) }.joined(separator: "\n\n")
        case .har:
            return exportHAR(entries)
        }
    }

    // MARK: - Share sheet

    @MainActor
    public static func presentShareSheet(
        for entries: [NetworkEntry],
        format: Format,
        from viewController: UIViewController?
    ) {
        let text = export(entries: entries, format: format)
        let fileName: String
        switch format {
        case .json: fileName = "loupe_log.json"
        case .plainText: fileName = "loupe_log.txt"
        case .curl: fileName = "loupe_curl.sh"
        case .har: fileName = "loupe_log.har"
        }

        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? text.write(to: tmpURL, atomically: true, encoding: .utf8)

        let activity = UIActivityViewController(
            activityItems: [tmpURL],
            applicationActivities: nil
        )

        let presenter = viewController ?? UIApplication.shared.topViewController
        presenter?.present(activity, animated: true)
    }

    // MARK: - Copy to clipboard

    public static func copyToClipboard(_ string: String) {
        UIPasteboard.general.string = string
    }

    // MARK: - Private

    private static func exportJSON(_ entries: [NetworkEntry]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(entries),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "[]"
    }

    private static func exportText(_ entry: NetworkEntry) -> String {
        var lines: [String] = []
        lines.append("=== \(entry.method) \(entry.url.absoluteString) ===")
        lines.append("Status: \(entry.statusCode.map(String.init) ?? "—")")
        lines.append("Duration: \(entry.timing.formattedDuration)")
        lines.append("Date: \(entry.timing.startDate)")

        lines.append("\n--- Request Headers ---")
        entry.requestHeaders.sorted(by: { $0.key < $1.key }).forEach {
            lines.append("\($0.key): \($0.value)")
        }

        if let body = entry.requestBody, let text = body.utf8String {
            lines.append("\n--- Request Body ---")
            lines.append(text)
        }

        lines.append("\n--- Response Headers ---")
        entry.responseHeaders.sorted(by: { $0.key < $1.key }).forEach {
            lines.append("\($0.key): \($0.value)")
        }

        if let body = entry.responseBody, let text = body.utf8String {
            lines.append("\n--- Response Body ---")
            lines.append(text)
        }

        if let err = entry.error {
            lines.append("\n--- Error ---")
            lines.append(err.localizedDescription)
        }

        return lines.joined(separator: "\n")
    }

    private static func exportHAR(_ entries: [NetworkEntry]) -> String {
        var harEntries: [[String: Any]] = []

        for entry in entries {
            let requestHeaders = entry.requestHeaders.map { ["name": $0.key, "value": $0.value] }
            let responseHeaders = entry.responseHeaders.map { ["name": $0.key, "value": $0.value] }

            var request: [String: Any] = [
                "method": entry.method,
                "url": entry.url.absoluteString,
                "httpVersion": "HTTP/1.1",
                "headers": requestHeaders,
                "queryString": entry.queryParameters.map { ["name": $0.key, "value": $0.value] },
                "cookies": [],
                "headersSize": -1,
                "bodySize": entry.requestBody?.count ?? -1
            ]

            if let body = entry.requestBody, let text = body.utf8String {
                request["postData"] = [
                    "mimeType": entry.requestHeaders["Content-Type"] ?? "text/plain",
                    "text": text
                ]
            }

            let responseBody = entry.responseBody?.utf8String ?? ""
            let response: [String: Any] = [
                "status": entry.statusCode ?? 0,
                "statusText": HTTPURLResponse.localizedString(forStatusCode: entry.statusCode ?? 0),
                "httpVersion": "HTTP/1.1",
                "headers": responseHeaders,
                "cookies": [],
                "content": [
                    "size": entry.responseSize,
                    "mimeType": entry.responseHeaders["Content-Type"] ?? "application/octet-stream",
                    "text": responseBody
                ],
                "redirectURL": "",
                "headersSize": -1,
                "bodySize": entry.responseSize
            ]

            let timings: [String: Any] = [
                "send": 0,
                "wait": Int((entry.timing.timeToFirstByte ?? 0) * 1000),
                "receive": Int((entry.timing.downloadDuration ?? 0) * 1000)
            ]

            let harEntry: [String: Any] = [
                "startedDateTime": ISO8601DateFormatter().string(from: entry.timing.startDate),
                "time": Int((entry.timing.totalDuration ?? 0) * 1000),
                "request": request,
                "response": response,
                "timings": timings,
                "cache": [:]
            ]
            harEntries.append(harEntry)
        }

        let har: [String: Any] = [
            "log": [
                "version": "1.2",
                "creator": ["name": "Loupe", "version": "1.0"],
                "entries": harEntries
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: har, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}

