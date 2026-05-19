import SwiftUI
import Combine

/// Middle column: searchable, filterable table of network entries.
struct MacConsoleView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var client: RemoteClient
    @State private var search = ""
    @State private var debouncedSearch = ""
    @State private var methodFilter = "All"
    @State private var semanticSearchOn = false
    @State private var debounceTask: DispatchWorkItem?

    private let methods = ["All", "GET", "POST", "PUT", "PATCH", "DELETE"]

    var filtered: [MacNetworkEntry] {
        let q = debouncedSearch
        let literal = appState.entries.filter { entry in
            let matchesSearch: Bool = {
                guard !q.isEmpty, !semanticSearchOn else { return true }
                if entry.url.absoluteString.localizedCaseInsensitiveContains(q) { return true }
                if entry.host.localizedCaseInsensitiveContains(q) { return true }
                if entry.path.localizedCaseInsensitiveContains(q) { return true }
                if let code = entry.statusCode, String(code).contains(q) { return true }
                for (k, v) in entry.requestHeaders {
                    if k.localizedCaseInsensitiveContains(q) || v.localizedCaseInsensitiveContains(q) { return true }
                }
                for (k, v) in entry.queryParameters {
                    if k.localizedCaseInsensitiveContains(q) || v.localizedCaseInsensitiveContains(q) { return true }
                }
                if let body = entry.responseBody,
                   let text = String(data: body, encoding: .utf8),
                   text.localizedCaseInsensitiveContains(q) { return true }
                if let body = entry.requestBody,
                   let text = String(data: body, encoding: .utf8),
                   text.localizedCaseInsensitiveContains(q) { return true }
                return false
            }()
            let matchesMethod = methodFilter == "All" || entry.method == methodFilter
            return matchesSearch && matchesMethod
        }

        guard semanticSearchOn,
              !q.trimmingCharacters(in: .whitespaces).isEmpty
        else { return literal }

        let ranked = MacSemanticSearch.shared.rank(literal, query: q)
        return ranked.isEmpty ? literal : ranked
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search URL, host, path, body, status…", text: $search)
                    .textFieldStyle(.roundedBorder)
                if !search.isEmpty {
                    Button { search = ""; debouncedSearch = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                if MacSemanticSearch.shared.isAvailable {
                    Button {
                        semanticSearchOn.toggle()
                    } label: {
                        Image(systemName: semanticSearchOn ? "sparkles" : "sparkle")
                            .foregroundStyle(semanticSearchOn ? Color.blue : Color.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help(semanticSearchOn ? "Disable semantic search" : "Enable semantic search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            // Filter bar
            HStack(spacing: 8) {
                Picker("Method", selection: $methodFilter) {
                    ForEach(methods, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                Button(role: .destructive) {
                    appState.clearEntries()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .foregroundStyle(appState.entries.isEmpty ? Color.secondary : Color.red)
                }
                .buttonStyle(.plain)
                .disabled(appState.entries.isEmpty)
                .help("Clear all entries")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            if filtered.isEmpty {
                emptyState
            } else {
                let pinned = filtered.filter(\.isPinned)
                let unpinned = filtered.filter { !$0.isPinned }
                List(selection: Binding(
                    get:  { appState.selected?.id },
                    set:  { id in appState.selected = filtered.first { $0.id == id } }
                )) {
                    if !pinned.isEmpty {
                        Section("📌 Pinned (\(pinned.count))") {
                            ForEach(pinned) { entry in
                                MacEntryRow(entry: entry)
                                    .tag(entry.id)
                                    .contextMenu { pinMenu(for: entry) }
                            }
                        }
                    }
                    if !unpinned.isEmpty {
                        Section(pinned.isEmpty ? "" : "All requests") {
                            ForEach(unpinned) { entry in
                                MacEntryRow(entry: entry)
                                    .tag(entry.id)
                                    .contextMenu { pinMenu(for: entry) }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            .onChange(of: search) { newValue in
                debounceTask?.cancel()
                let task = DispatchWorkItem { debouncedSearch = newValue }
                debounceTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
            }

            // Status bar
            HStack {
                Text("\(filtered.count) of \(appState.entries.count) request\(appState.entries.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if client.isConnecting {
                    ProgressView().scaleEffect(0.5)
                    Text("Connecting…").font(.caption).foregroundStyle(.secondary)
                } else if let device = client.connectedDevice {
                    Circle().fill(.green).frame(width: 7, height: 7)
                    Text(device.displayName).font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
        }
    }

    @ViewBuilder
    private func pinMenu(for entry: MacNetworkEntry) -> some View {
        Button(entry.isPinned ? "Unpin" : "Pin") {
            appState.setPinned(entry, pinned: !entry.isPinned)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "network.slash")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text(client.connectedDevice == nil ? "Select a device in the sidebar" : "No requests captured yet")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
