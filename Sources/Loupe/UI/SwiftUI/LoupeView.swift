import SwiftUI
import Combine

// MARK: - Endpoint category classifier

enum EndpointCategory {

    private static let genericSegments: Set<String> = [
        "api", "v1", "v2", "v3", "v4", "v5",
        "rest", "graphql", "gql", "rpc",
        "service", "services", "data", "public", "private",
        "mobile", "app", "apps", "web"
    ]

    static func classify(_ entry: NetworkEntry) -> String {
        let segments = entry.url.path
            .components(separatedBy: "/")
            .filter { !$0.isEmpty }

        for seg in segments {
            let lower = seg.lowercased()
            // Skip generic prefixes
            if genericSegments.contains(lower) { continue }
            // Skip version strings like v1, v2…
            if lower.hasPrefix("v"), lower.dropFirst().allSatisfy(\.isNumber) { continue }
            // Skip pure IDs (numeric)
            if seg.allSatisfy(\.isNumber) { continue }
            // Skip UUIDs
            if seg.count == 36, seg.filter({ $0 == "-" }).count == 4 { continue }
            // First meaningful segment becomes the category
            return seg.prefix(1).uppercased() + seg.dropFirst().lowercased()
        }
        return "Other"
    }
}

// MARK: - ViewModel

@MainActor
public final class LoupeViewModel: ObservableObject {

    @Published var allEntries:        [NetworkEntry] = []
    @Published var filter             = RequestFilter()
    @Published var searchText         = ""
    @Published var activeStatusFilter: StatusFilter  = .all
    @Published var isGrouped          = true
    @Published var semanticSearchOn   = false

    /// True when the device supports on-device semantic search.
    var semanticSearchAvailable: Bool { SemanticSearch.shared.isAvailable }

    // MARK: Filtered

    var filteredEntries: [NetworkEntry] {
        var f          = filter
        f.searchText   = semanticSearchOn ? "" : searchText
        f.statusFilter = activeStatusFilter
        let literal = f.apply(to: allEntries)

        guard semanticSearchOn,
              !searchText.trimmingCharacters(in: .whitespaces).isEmpty
        else { return literal }

        // Re-rank by semantic similarity; preserve all other filters.
        let ranked = SemanticSearch.shared.rank(literal, query: searchText)
        return ranked.isEmpty ? literal : ranked
    }

    /// Pinned entries that pass the current filter.
    var pinnedEntries: [NetworkEntry] {
        filteredEntries.filter(\.isPinned)
    }

    /// Non-pinned entries that pass the current filter.
    var unpinnedEntries: [NetworkEntry] {
        filteredEntries.filter { !$0.isPinned }
    }

    // MARK: Grouped

    var groupedEntries: [(category: String, entries: [NetworkEntry])] {
        var byCategory: [String: [NetworkEntry]] = [:]
        for e in filteredEntries {
            byCategory[EndpointCategory.classify(e), default: []].append(e)
        }
        return byCategory
            .sorted { a, b in
                if a.key == "Other" { return false }
                if b.key == "Other" { return true }
                return a.key < b.key
            }
            .map { (category: $0.key, entries: $0.value) }
    }

    // MARK: Stats

    var count2xx:     Int { allEntries.filter { $0.statusCode.map { (200..<300).contains($0) } ?? false }.count }
    var count3xx:     Int { allEntries.filter { $0.statusCode.map { (300..<400).contains($0) } ?? false }.count }
    var count4xx:     Int { allEntries.filter { $0.statusCode.map { (400..<500).contains($0) } ?? false }.count }
    var count5xx:     Int { allEntries.filter { $0.statusCode.map { (500..<600).contains($0) } ?? false }.count }
    var countFailed:  Int { allEntries.filter { $0.status == .failed }.count }
    var countPending: Int { allEntries.filter { !$0.status.isTerminal }.count }

    var activeFilterCount: Int {
        var n = 0
        if !searchText.isEmpty             { n += 1 }
        if activeStatusFilter != .all      { n += 1 }
        if filter.methodFilter != .all     { n += 1 }
        if !filter.excludedDomains.isEmpty { n += 1 }
        if filter.showOnlyFailed           { n += 1 }
        if filter.showOnlyMocked           { n += 1 }
        if filter.maxDuration < 5.0        { n += 1 }
        return n
    }

    func clearAllFilters() {
        filter            = RequestFilter()
        searchText        = ""
        activeStatusFilter = .all
    }

    // MARK: Private

    private var cancellables = Set<AnyCancellable>()

    init() {
        LogManager.shared.entriesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.allEntries = $0 }
            .store(in: &cancellables)
    }
}

// MARK: - Root View

public struct LoupeView: View {

    @Binding var isPresented: Bool
    @StateObject private var viewModel = LoupeViewModel()
    @ObservedObject private var themeManager = LoupeThemeManager.shared
    @State private var showFilters = false
    @State private var showInsights = false
    @State private var showConsole = false
    @State private var showAnalytics = false
    @State private var showCompose = false

    public init(isPresented: Binding<Bool>) { self._isPresented = isPresented }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.lpBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    statusStrip
                    if viewModel.activeFilterCount > 0 {
                        activeFilterBanner
                    }
                    Divider()
                    RequestListView()
                }
            }
            .navigationTitle("Loupe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { navToolbar }
            .lpNavigationBar()
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(themeManager.colorScheme)
        .environmentObject(viewModel)
        .sheet(isPresented: $showFilters) {
            FilterView(filter: $viewModel.filter, colorScheme: themeManager.colorScheme)
        }
        .sheet(isPresented: $showInsights) {
            InsightsView()
                .environmentObject(viewModel)
                .preferredColorScheme(themeManager.colorScheme)
        }
        .sheet(isPresented: $showConsole) {
            ConsoleView()
                .preferredColorScheme(themeManager.colorScheme)
        }
        .sheet(isPresented: $showAnalytics) {
            AnalyticsView()
                .preferredColorScheme(themeManager.colorScheme)
        }
        .sheet(isPresented: $showCompose) {
            ComposeView()
                .preferredColorScheme(themeManager.colorScheme)
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))

                TextField(
                    viewModel.semanticSearchOn
                        ? "Ask in plain English — “auth failed”, “slow images”…"
                        : "Search URL, method, status…",
                    text: $viewModel.searchText
                )
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 15))

                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(uiColor: .tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.semanticSearchAvailable {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            viewModel.semanticSearchOn.toggle()
                        }
                    } label: {
                        Image(systemName: viewModel.semanticSearchOn ? "sparkles" : "sparkle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(viewModel.semanticSearchOn ? Color.blue : Color(uiColor: .tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                    .help("Toggle semantic search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))

            filterButton
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var filterButton: some View {
        Button { showFilters = true } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 40, height: 38)
                    .background(
                        viewModel.filter.isActive
                            ? Color.blue.opacity(0.12)
                            : Color(uiColor: .tertiarySystemFill),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                    .foregroundStyle(viewModel.filter.isActive ? Color.blue : Color(uiColor: .label))

                if viewModel.filter.isActive {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                        .offset(x: 3, y: -3)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status strip

    private var statusStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if let env = Loupe.shared.configuration.environmentName, !env.isEmpty {
                    Text(env.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(envColor(env), in: Capsule())
                }
                statPill(
                    label: "All",
                    icon: "circle.grid.2x2.fill",
                    count: viewModel.allEntries.count,
                    color: Color(uiColor: .secondaryLabel),
                    filter: .all
                )
                if viewModel.count2xx > 0 {
                    statPill(label: "2xx", icon: "checkmark.circle.fill",    count: viewModel.count2xx,    color: .lpSuccess,  filter: .success)
                }
                if viewModel.count3xx > 0 {
                    statPill(label: "3xx", icon: "arrow.triangle.2.circlepath", count: viewModel.count3xx, color: .lpWarning,  filter: .redirect)
                }
                if viewModel.count4xx > 0 {
                    statPill(label: "4xx", icon: "exclamationmark.circle.fill", count: viewModel.count4xx, color: .lpDanger,   filter: .clientError)
                }
                if viewModel.count5xx > 0 {
                    statPill(label: "5xx", icon: "xmark.octagon.fill",          count: viewModel.count5xx, color: .lpCritical, filter: .serverError)
                }
                if viewModel.countFailed > 0 {
                    statPill(label: "ERR", icon: "bolt.slash.fill",             count: viewModel.countFailed, color: .red, filter: .failed)
                }
                if viewModel.countPending > 0 {
                    statPill(label: "···", icon: "clock.fill",                  count: viewModel.countPending, color: .blue, filter: .pending)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func statPill(label: String, icon: String, count: Int, color: Color, filter: StatusFilter) -> some View {
        let selected = viewModel.activeStatusFilter == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.activeStatusFilter = selected ? .all : filter
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected ? Color.white : color)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                selected ? color : color.opacity(0.10),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: count)
    }

    private func envColor(_ env: String) -> Color {
        switch env.lowercased() {
        case "production", "prod": return .red
        case "uat":                return .orange
        case "staging", "stg":     return .purple
        default:                   return .blue
        }
    }

    // MARK: - Active filter banner

    private var activeFilterBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.blue)

            Text("\(viewModel.activeFilterCount) filter\(viewModel.activeFilterCount == 1 ? "" : "s") active")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.blue)

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.clearAllFilters()
                }
            } label: {
                Text("Clear All")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.blue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.07))
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var navToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .frame(width: 28, height: 28)
                    .background(Color(uiColor: .tertiarySystemFill), in: Circle())
            }
            .buttonStyle(.plain)
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            Menu {
                Button {
                    showCompose = true
                } label: { Label("Compose Request", systemImage: "paperplane") }
                Button {
                    showConsole = true
                } label: { Label("Console", systemImage: "text.alignleft") }
                Button {
                    showAnalytics = true
                } label: { Label("Events", systemImage: "chart.line.uptrend.xyaxis") }
                Button {
                    showInsights = true
                } label: { Label("Insights", systemImage: "chart.bar.xaxis") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(uiColor: .label))
            }
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isGrouped.toggle()
                }
            } label: {
                Image(systemName: viewModel.isGrouped ? "list.bullet.indent" : "list.bullet")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(viewModel.isGrouped ? Color.blue : Color(uiColor: .secondaryLabel))
            }
            Button {
                themeManager.toggle()
            } label: {
                Image(systemName: themeManager.colorScheme == .dark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(themeManager.colorScheme == .dark ? Color.blue : Color.orange)
            }
        }
    }
}
