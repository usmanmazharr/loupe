import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationSplitView {
            DeviceListView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            content
                .navigationSplitViewColumnWidth(min: 360, ideal: 460)
        } detail: {
            detail
        }
        .navigationTitle("Loupe · \(appState.viewMode.rawValue)")
    }

    @ViewBuilder
    private var content: some View {
        switch appState.viewMode {
        case .network:  MacConsoleView()
        case .console:  MacConsoleLogView()
        case .events:   MacAnalyticsEventsView()
        case .insights: MacInsightsView()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch appState.viewMode {
        case .network:
            if let entry = appState.selected {
                MacRequestDetailView(entry: entry)
            } else {
                placeholder("arrow.left.doc.on.clipboard", "Select a request to inspect")
            }
        case .console:
            placeholder("text.alignleft",
                        "Console log details appear inline.\nSelect a row to copy or expand.")
        case .events:
            placeholder("chart.line.uptrend.xyaxis",
                        "Tap an event to expand its properties.")
        case .insights:
            placeholder("chart.bar.xaxis",
                        "Live snapshot of all captured requests.")
        }
    }

    private func placeholder(_ icon: String, _ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
