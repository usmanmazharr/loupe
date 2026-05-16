import SwiftUI

// MARK: - JSON Node

indirect enum MacJSONNode: Identifiable {
    case object(id: UUID, key: String?, children: [MacJSONNode])
    case array(id: UUID, key: String?, children: [MacJSONNode])
    case string(id: UUID, key: String?, value: String)
    case number(id: UUID, key: String?, value: Double)
    case bool(id: UUID, key: String?, value: Bool)
    case null(id: UUID, key: String?)

    var id: UUID {
        switch self {
        case .object(let id, _, _), .array(let id, _, _),
             .string(let id, _, _), .number(let id, _, _),
             .bool(let id, _, _), .null(let id, _):
            return id
        }
    }

    var key: String? {
        switch self {
        case .object(_, let k, _), .array(_, let k, _),
             .string(_, let k, _), .number(_, let k, _),
             .bool(_, let k, _), .null(_, let k):
            return k
        }
    }

    var isLeaf: Bool {
        switch self {
        case .object, .array: return false
        default: return true
        }
    }

    var valueDisplay: String {
        switch self {
        case .string(_, _, let v): return "\"\(v.count > 80 ? String(v.prefix(80)) + "…" : v)\""
        case .number(_, _, let v):
            return v.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", v) : String(v)
        case .bool(_, _, let v): return v ? "true" : "false"
        case .null: return "null"
        case .object(_, _, let c): return "{ \(c.count) field\(c.count == 1 ? "" : "s") }"
        case .array(_, _, let c): return "[ \(c.count) item\(c.count == 1 ? "" : "s") ]"
        }
    }

    static func parse(_ data: Data) -> MacJSONNode? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return nil }
        return node(from: obj, key: nil, path: "root")
    }

    private static func deterministicUUID(from path: String) -> UUID {
        let hash = path.utf8.reduce(into: [UInt8](repeating: 0, count: 16)) { result, byte in
            for i in 0..<16 {
                result[i] = result[i] &+ byte &* UInt8(truncatingIfNeeded: i &+ 1)
            }
        }
        return UUID(uuid: (hash[0], hash[1], hash[2], hash[3], hash[4], hash[5], hash[6], hash[7],
                           hash[8], hash[9], hash[10], hash[11], hash[12], hash[13], hash[14], hash[15]))
    }

    private static func node(from value: Any, key: String?, path: String) -> MacJSONNode {
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

// MARK: - JSON Tree View

struct MacJSONTreeView: View {

    let node: MacJSONNode
    let searchTerm: String
    @State private var expanded: Bool

    init(node: MacJSONNode, initiallyExpanded: Bool = true, searchTerm: String = "") {
        self.node = node
        self.searchTerm = searchTerm
        self._expanded = State(initialValue: searchTerm.isEmpty ? initiallyExpanded : Self.nodeContainsMatch(node, term: searchTerm))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowContent
            if expanded {
                childrenView
            }
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 4) {
            if !node.isLeaf {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() } }
            } else {
                Spacer().frame(width: 16)
            }

            if let key = node.key {
                let display = key.hasPrefix("[") ? key : "\"\(key)\":"
                highlight(display, baseColor: .blue)
                    .font(.system(size: 12, design: .monospaced))
            }

            let summary: String = {
                switch node {
                case .object(_, _, let c): return expanded ? "{" : "{ \(c.count) field\(c.count == 1 ? "" : "s") }"
                case .array(_, _, let c):  return expanded ? "[" : "[ \(c.count) item\(c.count == 1 ? "" : "s") ]"
                default: return node.valueDisplay
                }
            }()

            highlight(summary, baseColor: valueColor)
                .font(.system(size: 12, design: .monospaced))
                .lineLimit(1)

            Spacer()

            if !node.isLeaf, !searchTerm.isEmpty {
                let count = Self.countMatches(in: node, term: searchTerm)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.orange, in: Capsule())
                }
            }

            if node.isLeaf {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(node.valueDisplay, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !node.isLeaf {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            }
        }
        .id(node.id.uuidString)
    }

    @ViewBuilder
    private var childrenView: some View {
        switch node {
        case .object(_, _, let kids), .array(_, _, let kids):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(kids) { child in
                    MacJSONTreeView(node: child, initiallyExpanded: depth(child) < 2, searchTerm: searchTerm)
                        .padding(.leading, 16)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Highlight

    private func highlight(_ source: String, baseColor: Color) -> Text {
        guard !searchTerm.isEmpty else { return Text(source).foregroundColor(baseColor) }
        let lower = source.lowercased()
        let lowerTerm = searchTerm.lowercased()
        var result = Text("")
        var searchStart = lower.startIndex

        while let range = lower.range(of: lowerTerm, range: searchStart..<lower.endIndex) {
            let before = String(source[searchStart..<range.lowerBound])
            if !before.isEmpty { result = result + Text(before).foregroundColor(baseColor) }
            let match = String(source[range])
            var matchAttr = AttributedString(match)
            matchAttr.foregroundColor = .black
            matchAttr.backgroundColor = .yellow.opacity(0.7)
            matchAttr.font = .system(size: 12, design: .monospaced).bold()
            result = result + Text(matchAttr)
            searchStart = range.upperBound
        }
        let remaining = String(source[searchStart...])
        if !remaining.isEmpty { result = result + Text(remaining).foregroundColor(baseColor) }
        return result
    }

    private var valueColor: Color {
        switch node {
        case .object, .array: return .primary
        case .string: return .green
        case .number: return .orange
        case .bool: return .purple
        case .null: return .secondary
        }
    }

    // MARK: - Match counting

    static func countMatches(in node: MacJSONNode, term: String) -> Int {
        guard !term.isEmpty else { return 0 }
        return countRec(node, lowerTerm: term.lowercased())
    }

    static func nodeContainsMatch(_ node: MacJSONNode, term: String) -> Bool {
        countMatches(in: node, term: term) > 0
    }

    private static func countRec(_ node: MacJSONNode, lowerTerm: String) -> Int {
        var count = 0
        if let key = node.key, key.lowercased().contains(lowerTerm) { count += 1 }
        switch node {
        case .string(_, _, let v):
            if v.lowercased().contains(lowerTerm) { count += 1 }
        case .number(_, _, let v):
            if String(v).lowercased().contains(lowerTerm) { count += 1 }
        case .bool(_, _, let v):
            if String(v).lowercased().contains(lowerTerm) { count += 1 }
        case .object(_, _, let kids), .array(_, _, let kids):
            for child in kids { count += countRec(child, lowerTerm: lowerTerm) }
        case .null:
            if "null".contains(lowerTerm) { count += 1 }
        }
        return count
    }

    static func matchingNodeIDs(in node: MacJSONNode, term: String) -> [String] {
        guard !term.isEmpty else { return [] }
        var ids: [String] = []
        collectMatchIDs(node, lowerTerm: term.lowercased(), ids: &ids)
        return ids
    }

    private static func collectMatchIDs(_ node: MacJSONNode, lowerTerm: String, ids: inout [String]) {
        let nodeMatches: Bool
        switch node {
        case .string(_, let k, let v):
            nodeMatches = (k?.lowercased().contains(lowerTerm) ?? false) || v.lowercased().contains(lowerTerm)
        case .number(_, let k, let v):
            nodeMatches = (k?.lowercased().contains(lowerTerm) ?? false) || String(v).lowercased().contains(lowerTerm)
        case .bool(_, let k, let v):
            nodeMatches = (k?.lowercased().contains(lowerTerm) ?? false) || String(v).lowercased().contains(lowerTerm)
        case .null(_, let k):
            nodeMatches = (k?.lowercased().contains(lowerTerm) ?? false) || "null".contains(lowerTerm)
        case .object(_, let k, let kids), .array(_, let k, let kids):
            if k?.lowercased().contains(lowerTerm) ?? false { ids.append(node.id.uuidString) }
            for child in kids { collectMatchIDs(child, lowerTerm: lowerTerm, ids: &ids) }
            return
        }
        if nodeMatches { ids.append(node.id.uuidString) }
    }

    private func depth(_ node: MacJSONNode) -> Int {
        switch node {
        case .object(_, _, let c), .array(_, _, let c):
            return 1 + (c.map { depth($0) }.max() ?? 0)
        default: return 0
        }
    }
}
