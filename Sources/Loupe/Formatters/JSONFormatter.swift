import Foundation

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

public enum JSONFormatter {

    public static func parse(_ data: Data) -> JSONNode? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        return node(from: obj, key: nil, path: "root")
    }

    public static func parse(_ string: String) -> JSONNode? {
        guard let data = string.data(using: .utf8) else { return nil }
        return parse(data)
    }

    private static let preferredKeyOrder = [
        "statuscode", "status", "code",
        "message", "msg", "description",
        "data", "body", "result", "results", "response", "payload",
        "error", "errors", "errorMessage"
    ]

    private static func keyPriority(_ key: String) -> Int {
        let lower = key.lowercased()
        if let idx = preferredKeyOrder.firstIndex(of: lower) { return idx }
        return preferredKeyOrder.count
    }

    private static func sortedKeys(_ dict: [String: Any]) -> [(String, Any)] {
        dict.sorted { a, b in
            let pa = keyPriority(a.key)
            let pb = keyPriority(b.key)
            if pa != pb { return pa < pb }
            return a.key < b.key
        }
    }

    private static func deterministicUUID(from path: String) -> UUID {
        var h: UInt64 = 0xcbf29ce484222325
        for byte in path.utf8 {
            h ^= UInt64(byte)
            h &*= 0x100000001b3
        }
        let h2 = h &* 0x517cc1b727220a95
        return UUID(uuid: (
            UInt8(truncatingIfNeeded: h), UInt8(truncatingIfNeeded: h >> 8),
            UInt8(truncatingIfNeeded: h >> 16), UInt8(truncatingIfNeeded: h >> 24),
            UInt8(truncatingIfNeeded: h >> 32), UInt8(truncatingIfNeeded: h >> 40),
            UInt8(truncatingIfNeeded: h >> 48), UInt8(truncatingIfNeeded: h >> 56),
            UInt8(truncatingIfNeeded: h2), UInt8(truncatingIfNeeded: h2 >> 8),
            UInt8(truncatingIfNeeded: h2 >> 16), UInt8(truncatingIfNeeded: h2 >> 24),
            UInt8(truncatingIfNeeded: h2 >> 32), UInt8(truncatingIfNeeded: h2 >> 40),
            UInt8(truncatingIfNeeded: h2 >> 48), UInt8(truncatingIfNeeded: h2 >> 56)
        ))
    }

    private static func node(from value: Any, key: String?, path: String) -> JSONNode {
        let id = deterministicUUID(from: path)
        switch value {
        case let dict as [String: Any]:
            let children = sortedKeys(dict).map { node(from: $0.1, key: $0.0, path: "\(path).\($0.0)") }
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
