import Foundation
import SwiftUI

/// Central state for the macOS app — owns the RemoteClient and aggregates received entries.
@MainActor
final class AppState: ObservableObject {

    enum ViewMode: String, CaseIterable, Identifiable {
        case network = "Network"
        case compose = "Compose"
        case console = "Console"
        case events  = "Events"
        case insights = "Insights"
        case mocks    = "Mocks"
        var id: String { rawValue }
        var systemImage: String {
            switch self {
            case .network:  return "network"
            case .compose:  return "paperplane"
            case .console:  return "text.alignleft"
            case .events:   return "chart.line.uptrend.xyaxis"
            case .insights: return "chart.bar.xaxis"
            case .mocks:    return "server.rack"
            }
        }
    }

    @Published var entries:       [MacNetworkEntry] = []
    @Published var selected:      MacNetworkEntry?
    @Published var logs:          [MacLogMessage]    = []
    @Published var events:        [MacAnalyticsEvent] = []
    @Published var viewMode:      ViewMode = .network

    let client = RemoteClient()

    init() {
        client.onBatch = { [weak self] batch in
            guard let self else { return }
            var map = [UUID: MacNetworkEntry]()
            for e in self.entries { map[e.id] = e }
            for e in batch         { map[e.id] = e }
            self.entries = map.values.sorted { $0.timing.startDate > $1.timing.startDate }
        }

        client.onEntry = { [weak self] entry in
            guard let self else { return }
            if let idx = self.entries.firstIndex(where: { $0.id == entry.id }) {
                self.entries[idx] = entry
                if self.selected?.id == entry.id { self.selected = entry }
            } else {
                self.entries.insert(entry, at: 0)
            }
        }

        client.onClear = { [weak self] in
            guard let self else { return }
            // Match iOS behavior: keep pinned across clear.
            self.entries = self.entries.filter(\.isPinned)
            if let sel = self.selected, !sel.isPinned { self.selected = nil }
        }

        client.onHello = { _ in }

        client.onLogBatch = { [weak self] batch in
            guard let self else { return }
            var map = [UUID: MacLogMessage]()
            for m in self.logs { map[m.id] = m }
            for m in batch     { map[m.id] = m }
            self.logs = map.values.sorted { $0.timestamp < $1.timestamp }
        }
        client.onLogMessage = { [weak self] msg in
            guard let self else { return }
            if !self.logs.contains(where: { $0.id == msg.id }) {
                self.logs.append(msg)
            }
        }

        client.onAnalyticsBatch = { [weak self] batch in
            guard let self else { return }
            var map = [UUID: MacAnalyticsEvent]()
            for e in self.events { map[e.id] = e }
            for e in batch       { map[e.id] = e }
            self.events = map.values.sorted { $0.timestamp < $1.timestamp }
        }
        client.onAnalyticsEvent = { [weak self] event in
            guard let self else { return }
            if !self.events.contains(where: { $0.id == event.id }) {
                self.events.append(event)
            }
        }
    }

    // MARK: - Helpers

    var connectedDeviceName: String {
        client.connectedDevice?.displayName ?? "Not connected"
    }

    func clearEntries() {
        client.sendClear()
        // Local: drop everything except pinned.
        entries = entries.filter(\.isPinned)
        if let sel = selected, !sel.isPinned { selected = nil }
    }

    func setPinned(_ entry: MacNetworkEntry, pinned: Bool) {
        client.sendSetPinned(id: entry.id, pinned: pinned)
        // Optimistically update local copy.
        if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[idx].isPinned = pinned
            if selected?.id == entry.id { selected = entries[idx] }
        }
    }
}
