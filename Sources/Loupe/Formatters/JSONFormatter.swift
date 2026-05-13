import Foundation

/// Parses JSON data into a tree of `JSONNode` values for syntax-highlighted rendering.
public indirect enum JSONNode: Identifiable {
    case object(id: UUID = UUID(), key: String?, children: [JSONNode])
    case array(id: UUID = UUID(), key: String?, children: [JSONNode])
    case string(id: UUID = UUID(), key: String?, value: String)
    case number(id: UUID = UUID(), key: String?, value: Double)
    case bool(id: UUID = UUID(), key: String?, value: Bool)
    case null(id: UUID = UUID(), key: String?)

    public var id: UUID {
        switch self {
        case .object(let id, _, _): return id
        case .array(let id, _, _): return id
        case .string(let id, _, _): return id
        case .number(let id, _, _): return id
        case .bool(let id, _, _): return id
        case .null(let id, _): return id
        }
    }

    public var key: String? {
        switch self {
        case .object(_, let k, _): return k
        case .array(_, let k, _): return k
        case .string(_, let k, _): return k
        case .number(_, let k, _): return k
        case .bool(_, let k, _): return k
        case .null(_, let k): return k
        }
    }

    public var typeLabel: String {
        switch self {
        case .object(_, _, let c): return "{\(c.count)}"
        case .array(_, _, let c): return "[\(c.count)]"
        case .string(_, _, let v): return "\"\(v)\""
        case .number(_, _, let v):
            if v.truncatingRemainder(dividingBy: 1) == 0 { return String(format: "%.0f", v) }
            return String(v)
        case .bool(_, _, let v): return v ? "true" : "false"
        case .null: return "null"
        }
    }

    public var isLeaf: Bool {
        switch self {
        case .object, .array: return false
        default: return true
        }
    }
}

// MARK: - JSONFormatter

public enum JSONFormatter {

    /// Parses raw `Data` into a `JSONNode` tree. Returns nil for non-JSON data.
    public static func parse(_ data: Data) -> JSONNode? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        return node(from: obj, key: nil)
    }

    /// Parses a JSON string into a `JSONNode` tree.
    public static func parse(_ string: String) -> JSONNode? {
        guard let data = string.data(using: .utf8) else { return nil }
        return parse(data)
    }

    // MARK: Private

    private static func node(from value: Any, key: String?) -> JSONNode {
        switch value {
        case let dict as [String: Any]:
            let children = dict.sorted(by: { $0.key < $1.key }).map { node(from: $0.value, key: $0.key) }
            return .object(key: key, children: children)

        case let array as [Any]:
            let children = array.enumerated().map { node(from: $0.element, key: "[\($0.offset)]") }
            return .array(key: key, children: children)

        case let str as String:
            return .string(key: key, value: str)

        case let num as NSNumber:
            // Distinguish bool from numeric – NSNumber booleans have ObjC type 'B'
            if String(cString: num.objCType) == "c" {
                return .bool(key: key, value: num.boolValue)
            }
            return .number(key: key, value: num.doubleValue)

        default:
            // NSNull or unrecognised
            return .null(key: key)
        }
    }
}
