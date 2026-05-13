import SwiftUI

/// Collapsible, syntax-highlighted JSON tree rendered from `JSONNode`.
struct JSONTreeView: View {

    let node: JSONNode
    @State private var expanded: Bool

    init(node: JSONNode, initiallyExpanded: Bool = true) {
        self.node = node
        self._expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            rowContent
            if expanded {
                children
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private var rowContent: some View {
        HStack(spacing: 4) {
            // Expand/collapse toggle for containers
            if !node.isLeaf {
                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                    .onTapGesture { withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() } }
            } else {
                Spacer().frame(width: 16)
            }

            // Key
            if let key = node.key {
                Text(key.hasPrefix("[") ? key : "\"\(key)\":")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.jsonKey)
            }

            // Value / summary
            Text(valueSummary)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(valueColor)
                .lineLimit(1)

            Spacer()

            // Copy button for leaf nodes
            if node.isLeaf {
                Button {
                    ExportManager.copyToClipboard(node.typeLabel)
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

    // MARK: - Children

    @ViewBuilder
    private var children: some View {
        switch node {
        case .object(_, _, let kids), .array(_, _, let kids):
            VStack(alignment: .leading, spacing: 2) {
                ForEach(kids) { child in
                    JSONTreeView(node: child, initiallyExpanded: depth(child) < 2)
                        .padding(.leading, 16)
                }
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var valueSummary: String {
        switch node {
        case .object(_, _, let c): return expanded ? "{" : "{ \(c.count) field\(c.count == 1 ? "" : "s") }"
        case .array(_, _, let c):  return expanded ? "[" : "[ \(c.count) item\(c.count == 1 ? "" : "s") ]"
        case .string(_, _, let v): return "\"\(v.truncated(to: 80))\""
        case .number(_, _, let v):
            return v.truncatingRemainder(dividingBy: 1) == 0
                ? String(format: "%.0f", v) : String(v)
        case .bool(_, _, let v): return v ? "true" : "false"
        case .null: return "null"
        }
    }

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
