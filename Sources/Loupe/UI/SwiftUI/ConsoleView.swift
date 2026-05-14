import SwiftUI
import Combine

/// Standalone console view that mirrors `Loupe.shared.log(...)` and
/// any subsystems hooked via `startConsoleMirror(subsystems:)`.
public struct ConsoleView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ConsoleViewModel()
    @State private var search = ""
    @State private var levelFilter: LogMessage.Level? = nil

    private var filtered: [LogMessage] {
        model.messages.reversed().filter { m in
            (levelFilter == nil || m.level == levelFilter) &&
            (search.isEmpty
                || m.message.localizedCaseInsensitiveContains(search)
                || m.subsystem.localizedCaseInsensitiveContains(search)
                || m.category.localizedCaseInsensitiveContains(search))
        }
    }

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchAndFilters
                Divider()
                if filtered.isEmpty {
                    empty
                } else {
                    List(filtered) { msg in
                        row(msg)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .background(Color.lpBackground.ignoresSafeArea())
            .navigationTitle("Console")
            .navigationBarTitleDisplayMode(.inline)
            .lpNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LPBackButton { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        Task { await LogMessageStore.shared.clearAll() }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.messages.isEmpty)
                }
            }
        }
    }

    private var searchAndFilters: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                TextField("Search messages, subsystem, category…", text: $search)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 14))
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    levelPill(nil, label: "All", color: .secondary)
                    ForEach(LogMessage.Level.allCases, id: \.self) { lvl in
                        levelPill(lvl, label: lvl.displayName, color: color(for: lvl))
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
    }

    private func levelPill(_ level: LogMessage.Level?, label: String, color: Color) -> some View {
        let selected = levelFilter == level
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { levelFilter = selected ? nil : level }
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? Color.white : color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? color : color.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ m: LogMessage) -> some View {
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
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .lineLimit(1)
                    }
                    if !m.category.isEmpty {
                        Text("· \(m.category)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(m.timestamp, style: .time)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
                Text(m.message)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(uiColor: .label))
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No log messages")
                .foregroundStyle(.secondary)
            Text("Call Loupe.shared.log(\"…\") to add one.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func color(for level: LogMessage.Level) -> Color {
        switch level {
        case .trace, .debug:   return Color(uiColor: .systemGray)
        case .info, .notice:   return .blue
        case .warning:         return .orange
        case .error:           return .red
        case .fault:           return .purple
        }
    }
}

// MARK: - View model

@MainActor
final class ConsoleViewModel: ObservableObject {
    @Published var messages: [LogMessage] = []
    private var cancellables = Set<AnyCancellable>()
    init() {
        LogMessageStore.shared.messagesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.messages = $0 }
            .store(in: &cancellables)
    }
}
