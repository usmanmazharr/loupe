import SwiftUI

/// Collapsible, syntax-highlighted JSON tree rendered from `JSONNode`.
struct JSONTreeView: View {

    let node: JSONNode
    let searchTerm: String
    @State private var expanded: Bool

    init(node: JSONNode, initiallyExpanded: Bool = true, searchTerm: String = "") {
        self.node = node
        self.searchTerm = searchTerm
        self._expanded = State(initialValue: searchTerm.isEmpty ? initiallyExpanded : Self.nodeContainsMatch(node, term: searchTerm))
    }

    private var effectiveExpanded: Bool {
        if !searchTerm.isEmpty, Self.nodeContainsMatch(node, term: searchTerm) {
            return true
        }
        return expanded
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowContent
            if effectiveExpanded {
                children
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 4) {
            if !node.isLeaf {
                Image(systemName: effectiveExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() } }
            } else {
                Spacer().frame(width: 16)
            }

            if let key = node.key {
                highlightedKeyText(key)
            }

            highlightedValueText
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
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !node.isLeaf {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            }
        }
        .contextMenu {
            if node.isLeaf {
                Button { ExportManager.copyToClipboard(node.typeLabel) } label: { Label("Copy Value", systemImage: "doc.on.doc") }
            }
            if let key = node.key {
                Button { ExportManager.copyToClipboard(key) } label: { Label("Copy Key", systemImage: "textformat") }
            }
        }
        .id(node.id.uuidString)
    }

    // MARK: - Children

    @ViewBuilder
    private var children: some View {
        switch node {
        case .object(_, _, let kids), .array(_, _, let kids):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(kids) { child in
                    JSONTreeView(node: child, initiallyExpanded: depth(child) < 2, searchTerm: searchTerm)
                        .padding(.leading, 16)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Highlighted Text

    private func highlightedKeyText(_ key: String) -> Text {
        let display = key.hasPrefix("[") ? key : "\"\(key)\":"
        if searchTerm.isEmpty { return Text(display).font(.system(size: 12, design: .monospaced)).foregroundColor(.jsonKey) }
        return Self.highlight(display, term: searchTerm, baseColor: .jsonKey)
    }

    private var highlightedValueText: some View {
        let isExpanded = effectiveExpanded
        let summary: String = {
            switch node {
            case .object(_, _, let c): return isExpanded ? "{" : "{ \(c.count) field\(c.count == 1 ? "" : "s") }"
            case .array(_, _, let c):  return isExpanded ? "[" : "[ \(c.count) item\(c.count == 1 ? "" : "s") ]"
            case .string(_, _, let v): return "\"\(v.truncated(to: 80))\""
            case .number(_, _, let v):
                return v.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", v) : String(v)
            case .bool(_, _, let v): return v ? "true" : "false"
            case .null: return "null"
            }
        }()
        if searchTerm.isEmpty {
            return Self.highlight(summary, term: "", baseColor: valueColor)
                .font(.system(size: 12, design: .monospaced))
        }
        return Self.highlight(summary, term: searchTerm, baseColor: valueColor)
            .font(.system(size: 12, design: .monospaced))
    }

    static func highlight(_ source: String, term: String, baseColor: Color) -> Text {
        guard !term.isEmpty else { return Text(source).foregroundColor(baseColor) }
        let lower = source.lowercased()
        let lowerTerm = term.lowercased()
        var result = Text("")
        var searchStart = lower.startIndex

        while let range = lower.range(of: lowerTerm, range: searchStart..<lower.endIndex) {
            let before = String(source[searchStart..<range.lowerBound])
            if !before.isEmpty {
                result = result + Text(before).foregroundColor(baseColor)
            }
            let match = String(source[range])
            var matchAttr = AttributedString(match)
            matchAttr.foregroundColor = .black
            matchAttr.backgroundColor = Color.yellow.opacity(0.7)
            matchAttr.font = .system(size: 12, design: .monospaced).bold()
            result = result + Text(matchAttr)
            searchStart = range.upperBound
        }
        let remaining = String(source[searchStart...])
        if !remaining.isEmpty {
            result = result + Text(remaining).foregroundColor(baseColor)
        }
        return result
    }

    // MARK: - Match counting

    static func countMatches(in node: JSONNode, term: String) -> Int {
        guard !term.isEmpty else { return 0 }
        let lowerTerm = term.lowercased()
        return countMatchesRecursive(node, lowerTerm: lowerTerm)
    }

    private static func countMatchesRecursive(_ node: JSONNode, lowerTerm: String) -> Int {
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
            for child in kids { count += countMatchesRecursive(child, lowerTerm: lowerTerm) }
        case .null:
            if "null".contains(lowerTerm) { count += 1 }
        }
        return count
    }

    static func nodeContainsMatch(_ node: JSONNode, term: String) -> Bool {
        countMatches(in: node, term: term) > 0
    }

    static func matchingNodeIDs(in node: JSONNode, term: String) -> [String] {
        guard !term.isEmpty else { return [] }
        var ids: [String] = []
        collectMatchIDs(node, lowerTerm: term.lowercased(), ids: &ids)
        return ids
    }

    private static func collectMatchIDs(_ node: JSONNode, lowerTerm: String, ids: inout [String]) {
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

    // MARK: - Helpers

    private var valueColor: Color {
        switch node {
        case .object, .array: return .primary
        case .string: return .jsonString
        case .number: return .jsonNumber
        case .bool: return .jsonBool
        case .null: return .jsonNull
        }
    }

    private func depth(_ node: JSONNode) -> Int {
        switch node {
        case .object(_, _, let c), .array(_, _, let c):
            return 1 + (c.map { depth($0) }.max() ?? 0)
        default: return 0
        }
    }
}
