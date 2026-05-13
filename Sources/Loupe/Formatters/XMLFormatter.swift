import Foundation

/// Minimal XML pretty-printer using `XMLParser`.
public enum XMLFormatter {

    /// Returns indented XML string, or nil if the input is not valid XML.
    public static func prettyPrint(_ data: Data) -> String? {
        let delegate = XMLPrettyPrinter()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return delegate.result
    }

    public static func prettyPrint(_ string: String) -> String? {
        guard let data = string.data(using: .utf8) else { return nil }
        return prettyPrint(data)
    }
}

// MARK: - XMLPrettyPrinter (delegate)

private final class XMLPrettyPrinter: NSObject, XMLParserDelegate {

    var result: String = ""
    private var depth: Int = 0
    private var indentUnit: String = "  "

    private var indent: String { String(repeating: indentUnit, count: depth) }

    func parserDidStartDocument(_ parser: XMLParser) {
        result = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String] = [:]
    ) {
        result += "\(indent)<\(elementName)"
        for (key, value) in attributes.sorted(by: { $0.key < $1.key }) {
            result += " \(key)=\"\(value)\""
        }
        result += ">\n"
        depth += 1
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        depth -= 1
        result += "\(indent)</\(elementName)>\n"
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        result += "\(indent)\(trimmed)\n"
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        result = ""
    }
}
