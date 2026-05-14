import SwiftUI

/// Console (OSLog mirror) — list of log messages streamed from iOS.
struct MacConsoleLogView: View {

    @EnvironmentObject private var appState: AppState
    @State private var search: String = ""
    @State private var levelFilter: MacLogMessage.Level? = nil

    private var filtered: [MacLogMessage] {
        appState.logs.reversed().filter { m in
            (levelFilter == nil || m.level == levelFilter) &&
            (search.isEmpty
                || m.message.localizedCaseInsensitiveContains(search)
                || m.subsystem.localizedCaseInsensitiveContains(search)
                || m.category.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if filtered.isEmpty {
                empty
            } else {
                List(filtered) { msg in
                    row(msg)
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                        .listRowSeparator(.hidden)
                }
                .listStyle(.inset)
            }
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search messages, subsystem, category…", text: $search)
                    .textFieldStyle(.roundedBorder)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.lpSurface, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.top, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    pill(nil, label: "All")
                    ForEach(MacLogMessage.Level.allCases, id: \.self) { lvl in
                        pill(lvl, label: lvl.displayName)
                    }
                }
                .padding(.horizontal, 12)
            }
            .padding(.bottom, 8)
        }
    }

    private func pill(_ level: MacLogMessage.Level?, label: String) -> some View {
        let selected = levelFilter == level
        let tint = color(for: level)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { levelFilter = selected ? nil : level }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Color.white : tint)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(selected ? tint : tint.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ m: MacLogMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color(for: m.level))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(m.level.displayName.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(color(for: m.level), in: Capsule())
                    if !m.subsystem.isEmpty {
                        Text(m.subsystem)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if !m.category.isEmpty {
                        Text("· \(m.category)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(m.timestamp, style: .time)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Text(m.message)
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.lpSurface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.alignleft").font(.system(size: 36)).foregroundStyle(.tertiary)
            Text("No log messages").foregroundStyle(.secondary)
            Text("Logs sent via Loupe.shared.log(...) or startConsoleMirror will appear here.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func color(for level: MacLogMessage.Level?) -> Color {
        switch level {
        case .trace, .debug:   return .gray
        case .info, .notice:   return .blue
        case .warning:         return .orange
        case .error:           return .red
        case .fault:           return .purple
        case nil:              return .secondary
        }
    }
}
