import SwiftUI

// MARK: - JSON Node

indirect enum MacJSONNode: Identifiable {
    case object(id: UUID = UUID(), key: String?, children: [MacJSONNode])
    case array(id: UUID = UUID(), key: String?, children: [MacJSONNode])
    case string(id: UUID = UUID(), key: String?, value: String)
    case number(id: UUID = UUID(), key: String?, value: Double)
    case bool(id: UUID = UUID(), key: String?, value: Bool)
    case null(id: UUID = UUID(), key: String?)

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
        return node(from: obj, key: nil)
    }

    private static func node(from value: Any, key: String?) -> MacJSONNode {
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
            if String(cString: num.objCType) == "c" {
                return .bool(key: key, value: num.boolValue)
            }
            return .number(key: key, value: num.doubleValue)
        default:
            return .null(key: key)
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
            result = result + Text(match).foregroundColor(.black).bold()
                .background(RoundedRectangle(cornerRadius: 2).fill(Color.yellow.opacity(0.7)))
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

    private func depth(_ node: MacJSONNode) -> Int {
        switch node {
        case .object(_, _, let c), .array(_, _, let c):
            return 1 + (c.map { depth($0) }.max() ?? 0)
        default: return 0
        }
    }
}
