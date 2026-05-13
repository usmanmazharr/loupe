import SwiftUI

/// Analytics events streamed from iOS — filter by provider (Mixpanel, Firebase, …).
struct MacAnalyticsEventsView: View {

    @EnvironmentObject private var appState: AppState
    @State private var search: String = ""
    @State private var selectedProvider: String? = nil
    @State private var selectedScreen: String? = nil
    @State private var groupByScreen = true
    @State private var expandedID: UUID? = nil

    private var providers: [String] {
        Array(Set(appState.events.map(\.provider))).sorted()
    }

    private var screens: [String] {
        Array(Set(appState.events.compactMap(\.screen))).sorted()
    }

    private var filtered: [MacAnalyticsEvent] {
        appState.events.reversed().filter { e in
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

    private var grouped: [(screen: String, events: [MacAnalyticsEvent])] {
        var order: [String] = []
        var buckets: [String: [MacAnalyticsEvent]] = [:]
        for e in filtered {
            let key = e.screen ?? "Unknown"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(e)
        }
        return order.map { (screen: $0, events: buckets[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if filtered.isEmpty {
                empty
            } else if groupByScreen {
                groupedList
            } else {
                flatList
            }
        }
    }

    private var flatList: some View {
        List(filtered) { event in
            row(event)
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                .listRowSeparator(.hidden)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expandedID = expandedID == event.id ? nil : event.id
                    }
                }
        }
        .listStyle(.inset)
    }

    private var groupedList: some View {
        List {
            ForEach(grouped, id: \.screen) { group in
                Section {
                    ForEach(group.events) { event in
                        row(event)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .listRowSeparator(.hidden)
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
        .listStyle(.inset)
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search event name, property, value, screen…", text: $search)
                    .textFieldStyle(.roundedBorder)
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
                Button {
                    groupByScreen.toggle()
                } label: {
                    Image(systemName: groupByScreen ? "rectangle.stack.fill" : "rectangle.stack")
                        .foregroundStyle(groupByScreen ? Color.blue : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help("Group by screen")
                Text("\(filtered.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.mfSurface, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.top, 10)

            if !providers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        providerPill(nil, label: "All", count: appState.events.count)
                        ForEach(providers, id: \.self) { p in
                            providerPill(p, label: p, count: appState.events.filter { $0.provider == p }.count)
                        }
                    }
                    .padding(.horizontal, 12)
                }
            }

            if !screens.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        screenPill(nil, label: "All screens", count: nil)
                        ForEach(screens, id: \.self) { s in
                            screenPill(s, label: s,
                                       count: appState.events.filter { $0.screen == s }.count)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 8)
            }
        }
    }

    private func screenPill(_ screen: String?, label: String, count: Int?) -> some View {
        let selected = selectedScreen == screen
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedScreen = selected ? nil : screen
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "rectangle.on.rectangle").font(.system(size: 9))
                Text(label).font(.system(size: 11, weight: .semibold))
                if let count {
                    Text("\(count)").font(.system(size: 10, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(selected ? Color.white : Color.mfAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(selected ? Color.mfAccent : Color.mfAccent.opacity(0.10), in: Capsule())
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
                Text(label).font(.system(size: 11, weight: .semibold))
                Text("\(count)").font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundStyle(selected ? Color.white : tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(selected ? tint : tint.opacity(0.10), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func row(_ event: MacAnalyticsEvent) -> some View {
        let tint = color(for: event.provider)
        let expanded = expandedID == event.id
        return HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3).frame(maxHeight: .infinity)
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
                        .lineLimit(1)
                    Spacer()
                    if let screen = event.screen {
                        Text(screen)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.mfAccent.opacity(0.12), in: Capsule())
                    }
                    Text(event.timestamp, style: .time)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                if expanded {
                    if event.properties.isEmpty {
                        Text("No properties").font(.system(size: 11)).foregroundStyle(.tertiary)
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
                                        .textSelection(.enabled)
                                    Spacer()
                                }
                            }
                        }
                    }
                } else if !event.propertiesPreview.isEmpty {
                    Text(event.propertiesPreview)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.mfSurface, in: RoundedRectangle(cornerRadius: 10))
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No events captured").foregroundStyle(.secondary)
            Text("Events sent via Loupe.shared.trackEvent(...) will appear here.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func color(for provider: String) -> Color {
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
