import SwiftUI
import Combine

struct RequestListView: View {

    @EnvironmentObject private var viewModel: LoupeViewModel
    @State private var collapsedCategories: Set<String> = []

    var body: some View {
        Group {
            if viewModel.filteredEntries.isEmpty {
                emptyState
            } else if viewModel.isGrouped {
                groupedList
            } else {
                flatList
            }
        }
        .toolbar { toolbarContent }
    }

    // MARK: - Row builder shared by pinned + flat lists

    @ViewBuilder
    private func entryRow(_ entry: NetworkEntry) -> some View {
        NavigationLink(destination: RequestDetailView(entry: entry)) {
            EntryRow(entry: entry)
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                Task { await LogManager.shared.remove(ids: [entry.effectiveID]) }
            } label: { Label("Delete", systemImage: "trash") }
        }
        .swipeActions(edge: .leading) {
            Button {
                Task { await LogManager.shared.setPinned(!entry.isPinned, id: entry.effectiveID) }
            } label: {
                Label(entry.isPinned ? "Unpin" : "Pin",
                      systemImage: entry.isPinned ? "pin.slash.fill" : "pin.fill")
            }
            .tint(.yellow)

            Button {
                ExportManager.copyToClipboard(CURLGenerator.generate(from: entry))
            } label: { Label("cURL", systemImage: "terminal") }
                .tint(.indigo)
        }
    }

    // MARK: - Grouped list

    private var groupedList: some View {
        List {
            if !viewModel.pinnedEntries.isEmpty {
                Section {
                    ForEach(viewModel.pinnedEntries, id: \.effectiveID) { entry in
                        entryRow(entry)
                    }
                } header: {
                    CategoryHeader(
                        name: "📌 Pinned",
                        count: viewModel.pinnedEntries.count,
                        avgDuration: averageDuration(viewModel.pinnedEntries),
                        isCollapsed: false,
                        onTap: {}
                    )
                }
            }

            ForEach(viewModel.groupedEntries, id: \.category) { group in
                let unpinned = group.entries.filter { !$0.isPinned }
                if !unpinned.isEmpty {
                    Section {
                        if !collapsedCategories.contains(group.category) {
                            ForEach(unpinned, id: \.effectiveID) { entry in
                                entryRow(entry)
                            }
                        }
                    } header: {
                        CategoryHeader(
                            name: group.category,
                            count: unpinned.count,
                            avgDuration: averageDuration(unpinned),
                            isCollapsed: collapsedCategories.contains(group.category),
                            onTap: {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    if collapsedCategories.contains(group.category) {
                                        collapsedCategories.remove(group.category)
                                    } else {
                                        collapsedCategories.insert(group.category)
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.filteredEntries.map(\.effectiveID))
    }

    // MARK: - Flat list

    private var flatList: some View {
        List {
            if !viewModel.pinnedEntries.isEmpty {
                Section {
                    ForEach(viewModel.pinnedEntries, id: \.effectiveID) { entry in
                        entryRow(entry)
                    }
                } header: {
                    CategoryHeader(
                        name: "📌 Pinned",
                        count: viewModel.pinnedEntries.count,
                        avgDuration: averageDuration(viewModel.pinnedEntries),
                        isCollapsed: false,
                        onTap: {}
                    )
                }
            }

            ForEach(viewModel.unpinnedEntries, id: \.effectiveID) { entry in
                entryRow(entry)
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.filteredEntries.map(\.effectiveID))
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.activeFilterCount > 0 || !viewModel.searchText.isEmpty {
            EmptyStateView(kind: .noResults(query: viewModel.searchText))
        } else {
            EmptyStateView(kind: .noRequests)
        }
    }

    // MARK: - Bottom toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .bottomBar) {
            Menu {
                Button {
                    ExportManager.presentShareSheet(for: viewModel.filteredEntries, format: .json, from: nil)
                } label: { Label("Export JSON", systemImage: "doc.text") }
                Button {
                    ExportManager.presentShareSheet(for: viewModel.filteredEntries, format: .har, from: nil)
                } label: { Label("Export HAR", systemImage: "doc.text.magnifyingglass") }
                Button {
                    ExportManager.presentShareSheet(for: viewModel.filteredEntries, format: .curl, from: nil)
                } label: { Label("Export cURL", systemImage: "terminal") }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .medium))
            }
            .disabled(viewModel.filteredEntries.isEmpty)

            Spacer()

            VStack(spacing: 0) {
                Text("\(viewModel.filteredEntries.count)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(uiColor: .label))
                Text("request\(viewModel.filteredEntries.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
            }

            Spacer()

            Button(role: .destructive) {
                Task { await LogManager.shared.clearAll() }
            } label: {
                Text("Clear")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(viewModel.allEntries.isEmpty ? Color(uiColor: .tertiaryLabel) : Color.red)
            }
            .disabled(viewModel.allEntries.isEmpty)
        }
    }

    // MARK: - Helpers

    private func averageDuration(_ entries: [NetworkEntry]) -> TimeInterval? {
        let durations = entries.compactMap { $0.timing.totalDuration }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }
}

// MARK: - Category section header

private struct CategoryHeader: View {

    let name: String
    let count: Int
    let avgDuration: TimeInterval?
    let isCollapsed: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Category icon strip
                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor)
                    .frame(width: 3, height: 14)

                Text(name.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))

                Text("·")
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))

                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))

                if let avg = avgDuration {
                    Text("·")
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    Text("avg \(formatDuration(avg))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }

                Spacer()

                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var categoryColor: Color {
        // Deterministic color based on name hash
        let hash = abs(name.hashValue)
        let colors: [Color] = [.blue, .purple, .indigo, .teal, .cyan, .orange, .mint, .pink]
        return colors[hash % colors.count]
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        t < 1 ? String(format: "%.0fms", t * 1000) : String(format: "%.2fs", t)
    }
}

// MARK: - Entry row

private struct EntryRow: View {

    @ObservedObject var entry: NetworkEntry

    var body: some View {
        HStack(spacing: 12) {
            // Status accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 5) {
                // Top row: method + status + mock + in-progress
                HStack(spacing: 6) {
                    MethodBadge(method: entry.method)
                    StatusBadge(code: entry.statusCode, status: entry.status)

                    if entry.isMocked {
                        Text("MOCK")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.purple, in: Capsule())
                    }

                    if entry.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.yellow)
                    }

                    Spacer()

                    if entry.status == .inProgress {
                        ProgressView()
                            .scaleEffect(0.65)
                    } else {
                        Text(entry.timing.formattedDuration)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(durationColor)
                    }
                }

                // Path
                Text(entry.url.path.isEmpty ? "/" : entry.url.path)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(uiColor: .label))
                    .lineLimit(1)

                // Bottom row: host + size + time
                HStack(spacing: 6) {
                    Text(entry.host)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)

                    if entry.responseSize > 0 {
                        Text("·")
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                        Text(entry.responseSize.formattedSize)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                    }

                    Spacer()

                    Text(entry.timing.startDate, style: .time)
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
            }
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 12)
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var accentColor: Color {
        if let code = entry.statusCode { return Color.statusColor(for: code) }
        if entry.status == .failed     { return .lpDanger }
        if entry.status == .inProgress { return .blue }
        return Color(uiColor: .tertiaryLabel)
    }

    private var durationColor: Color {
        guard let d = entry.timing.totalDuration else { return Color(uiColor: .secondaryLabel) }
        if d < 0.3 { return .lpSuccess }
        if d < 1.0 { return .lpWarning }
        return .lpDanger
    }
}
