import SwiftUI
import Combine

/// Analytics events list — Mixpanel, Firebase, Adjust, Insider, Segment, …
/// Populated by `Loupe.shared.trackEvent(...)`.
public struct AnalyticsView: View {

    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = AnalyticsViewModel()
    @State private var search = ""
    @State private var selectedProvider: String? = nil
    @State private var selectedScreen: String? = nil
    @State private var groupByScreen = false
    @State private var expandedID: UUID? = nil

    private var providers: [String] {
        Array(Set(model.events.map(\.provider))).sorted()
    }

    private var screens: [String] {
        Array(Set(model.events.compactMap(\.screen))).sorted()
    }

    private var filtered: [AnalyticsEvent] {
        model.events.reversed().filter { e in
            (selectedProvider == nil || e.provider == selectedProvider) &&
            (selectedScreen   == nil || e.screen   == selectedScreen) &&
            (search.isEmpty
                || e.name.localizedCaseInsensitiveContains(search)
                || e.provider.localizedCaseInsensitiveContains(search)
                || (e.screen?.localizedCaseInsensitiveContains(search) ?? false)
                || e.properties.contains { $0.key.localizedCaseInsensitiveContains(search)
                                        || $0.value.localizedCaseInsensitiveContains(search) })
        }
    }

    /// Returns events grouped by `screen` (preserving relative order).
    private var grouped: [(screen: String, events: [AnalyticsEvent])] {
        var seenOrder: [String] = []
        var buckets: [String: [AnalyticsEvent]] = [:]
        for e in filtered {
            let key = e.screen ?? "Unknown"
            if buckets[key] == nil { seenOrder.append(key) }
            buckets[key, default: []].append(e)
        }
        return seenOrder.map { (screen: $0, events: buckets[$0] ?? []) }
    }

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchBar
                if !providers.isEmpty { providerStrip }
                if !screens.isEmpty   { screenStrip }
                Divider()
                if filtered.isEmpty {
                    empty
                } else if groupByScreen {
                    groupedList
                } else {
                    flatList
                }
            }
            .background(Color.lpBackground.ignoresSafeArea())
            .navigationTitle("Events")
            .navigationBarTitleDisplayMode(.inline)
            .lpNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LPBackButton { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { groupByScreen.toggle() }
                    } label: {
                        Image(systemName: groupByScreen ? "rectangle.stack.fill" : "rectangle.stack")
                            .foregroundStyle(groupByScreen ? Color.blue : Color(uiColor: .label))
                    }
                    .help("Group by screen")
                    Text("\(filtered.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        Task { await AnalyticsEventStore.shared.clearAll() }
                    } label: { Image(systemName: "trash") }
                    .disabled(model.events.isEmpty)
                }
            }
        }
    }

    private var flatList: some View {
        List(filtered) { event in
            row(event)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedID = expandedID == event.id ? nil : event.id
                    }
                }
        }
        .listStyle(.plain)
    }

    private var groupedList: some View {
        List {
            ForEach(grouped, id: \.screen) { group in
                Section {
                    ForEach(group.events) { event in
                        row(event)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    expandedID = expandedID == event.id ? nil : event.id
                                }
                            }
                    }
                } header: {
                    HStack(spacing: 6) {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(group.screen)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text("·").foregroundStyle(.tertiary)
                        Text("\(group.events.count)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
            TextField("Search event name, property, value…", text: $search)
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
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var providerStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                providerPill(nil, label: "All", count: model.events.count)
                ForEach(providers, id: \.self) { p in
                    providerPill(p, label: p, count: model.events.filter { $0.provider == p }.count)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private var screenStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                screenPill(nil, label: "All screens")
                ForEach(screens, id: \.self) { s in
                    let count = model.events.filter { $0.screen == s }.count
                    screenPill(s, label: s, count: count)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }

    private func screenPill(_ screen: String?, label: String, count: Int? = nil) -> some View {
        let selected = selectedScreen == screen
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedScreen = selected ? nil : screen
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 9))
                Text(label).font(.system(size: 11, weight: .semibold))
                if let count {
                    Text("\(count)").font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(selected ? Color.white : Color.indigo)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(selected ? Color.indigo : Color.indigo.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func providerPill(_ provider: String?, label: String, count: Int) -> some View {
        let selected = selectedProvider == provider
        let tint = color(for: provider ?? "")
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedProvider = selected ? nil : provider
            }
        } label: {
            HStack(spacing: 5) {
                Circle().fill(tint).frame(width: 6, height: 6)
                Text(label).font(.system(size: 12, weight: .semibold))
                Text("\(count)").font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected ? Color.white : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? tint : tint.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ event: AnalyticsEvent) -> some View {
        let tint = color(for: event.provider)
        let expanded = expandedID == event.id
        return HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 3)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(event.provider.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(tint, in: Capsule())
                    Text(event.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .lineLimit(1)
                    Spacer()
                    if let screen = event.screen {
                        Text(screen)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.indigo.opacity(0.12), in: Capsule())
                    }
                    Text(event.timestamp, style: .time)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(Color(uiColor: .tertiaryLabel))
                }
                if expanded {
                    if event.properties.isEmpty {
                        Text("No properties")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(event.properties.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(k)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(minWidth: 100, alignment: .leading)
                                    Text(v)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(Color(uiColor: .label))
                                        .textSelection(.enabled)
                                    Spacer()
                                }
                            }
                        }
                    }
                } else if !event.propertiesPreview.isEmpty {
                    Text(event.propertiesPreview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.lpCardBackground, in: RoundedRectangle(cornerRadius: 10))
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No events captured")
                .foregroundStyle(.secondary)
            Text("Call Loupe.shared.trackEvent(\"…\", provider: \"Mixpanel\") next to each SDK call.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Stable color per provider name.
    private func color(for provider: String) -> Color {
        // Well-known SDKs get fixed colors; unknown providers hash into the palette.
        switch provider.lowercased() {
        case "mixpanel":   return .purple
        case "firebase":   return .orange
        case "adjust":     return .blue
        case "insider":    return .pink
        case "segment":    return .green
        case "amplitude":  return .indigo
        case "appsflyer":  return .teal
        case "branch":     return .mint
        case "":           return .gray
        default:
            let palette: [Color] = [.red, .yellow, .cyan, .brown, .indigo, .pink]
            return palette[abs(provider.hashValue) % palette.count]
        }
    }
}

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var events: [AnalyticsEvent] = []
    private var cancellables = Set<AnyCancellable>()
    init() {
        AnalyticsEventStore.shared.eventsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.events = $0 }
            .store(in: &cancellables)
    }
}
