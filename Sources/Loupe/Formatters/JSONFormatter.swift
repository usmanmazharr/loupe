import Foundation

/// Parses JSON data into a tree of `JSONNode` values for syntax-highlighted rendering.
public indirect enum JSONNode: Identifiable {
    case object(id: UUID, key: String?, children: [JSONNode])
    case array(id: UUID, key: String?, children: [JSONNode])
    case string(id: UUID, key: String?, value: String)
    case number(id: UUID, key: String?, value: Double)
    case bool(id: UUID, key: String?, value: Bool)
    case null(id: UUID, key: String?)

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
        return node(from: obj, key: nil, path: "root")
    }

    /// Parses a JSON string into a `JSONNode` tree.
    public static func parse(_ string: String) -> JSONNode? {
        guard let data = string.data(using: .utf8) else { return nil }
        return parse(data)
    }

    // MARK: Private

    private static func deterministicUUID(from path: String) -> UUID {
        let hash = path.utf8.reduce(into: [UInt8](repeating: 0, count: 16)) { result, byte in
            for i in 0..<16 {
                result[i] = result[i] &+ byte &* UInt8(truncatingIfNeeded: i &+ 1)
            }
        }
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]))
    }

    private static func node(from value: Any, key: String?, path: String) -> JSONNode {
        let id = deterministicUUID(from: path)
        switch value {
        case let dict as [String: Any]:
            let children = dict.map { node(from: $0.value, key: $0.key, path: "\(path).\($0.key)") }
            return .object(id: id, key: key, children: children)

        case let array as [Any]:
            let children = array.enumerated().map { node(from: $0.element, key: "[\($0.offset)]", path: "\(path)[\($0.offset)]") }
            return .array(id: id, key: key, children: children)

        case let str as String:
            return .string(id: id, key: key, value: str)

        case let num as NSNumber:
            if String(cString: num.objCType) == "c" {
                return .bool(id: id, key: key, value: num.boolValue)
            }
            return .number(id: id, key: key, value: num.doubleValue)

        default:
            return .null(id: id, key: key)
        }
    }
}
