import Foundation

/// Formats raw body `Data` into a displayable string for a given content type.
public enum BodyFormatter {

    public enum FormattedBody {
        case text(String)
        case json(String, JSONNode?)   // raw pretty string + parsed tree
        case xml(String)
        case image(Data, String)       // raw data + mime subtype
        case pdf(Data)
        case binary(String)            // description only
        case empty
    }

    /// Inspects `data` using the declared `contentType` and returns the best representation.
    public static func format(data: Data?, contentType: ContentType) -> FormattedBody {
        guard let data, !data.isEmpty else { return .empty }

        switch contentType {
        case .json, .graphQL:
            let raw = data.prettyPrintedJSON ?? data.utf8String ?? "<undecodable>"
            let tree = JSONFormatter.parse(data)
            return .json(raw, tree)

        case .xml, .html:
            let formatted = XMLFormatter.prettyPrint(data)
                ?? data.utf8String
                ?? "<undecodable>"
            return .xml(formatted)

        case .image(let sub):
            return .image(data, sub)

        case .pdf:
            return .pdf(data)

        case .binary:
            return .binary("Binary data · \(data.formattedSize)")

        case .multipart:
            // Best-effort: show as text
            let text = data.utf8String ?? "Binary multipart data · \(data.formattedSize)"
            return .text(text)

        case .plainText, .unknown:
            if data.isBinary {
                return .binary("Binary data · \(data.formattedSize)")
            }
            if let str = data.utf8String {
                // Auto-detect JSON even when the Content-Type is wrong
                if str.trimmingCharacters(in: .whitespacesAndNewlines).first.map({ $0 == "{" || $0 == "[" }) ?? false,
                   let pretty = data.prettyPrintedJSON {
                    return .json(pretty, JSONFormatter.parse(data))
                }
                return .text(str)
            }
            return .binary("Binary data · \(data.formattedSize)")
        }
    }

    /// Converts `FormattedBody` to a plain string suitable for exporting.
    public static func plainText(from body: FormattedBody) -> String {
        switch body {
        case .text(let s): return s
        case .json(let s, _): return s
        case .xml(let s): return s
        case .image(_, let sub): return "<Image: \(sub)>"
        case .pdf: return "<PDF>"
        case .binary(let d): return d
        case .empty: return "(empty)"
        }
    }
}
