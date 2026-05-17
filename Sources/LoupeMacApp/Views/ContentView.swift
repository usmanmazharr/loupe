import SwiftUI

struct ContentView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var client: RemoteClient

    private var navigationTitle: String {
        var title = "Loupe · \(appState.viewMode.rawValue)"
        if let env = client.connectedDevice?.info?.environmentName, !env.isEmpty {
            title += " [\(env.uppercased())]"
        }
        return title
    }

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
        .navigationTitle(navigationTitle)
    }

    @ViewBuilder
    private var content: some View {
        switch appState.viewMode {
        case .network:  MacConsoleView()
        case .compose:  MacComposeView()
        case .console:  MacConsoleLogView()
        case .events:   MacAnalyticsEventsView()
        case .insights: MacInsightsView()
        case .mocks:    MacMockServerView()
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
        case .compose:
            placeholder("paperplane",
                        "Compose a request on the left.\nResponse appears inline.")
        case .console:
            placeholder("text.alignleft",
                        "Console log details appear inline.\nSelect a row to copy or expand.")
        case .events:
            placeholder("chart.line.uptrend.xyaxis",
                        "Tap an event to expand its properties.")
        case .insights:
            placeholder("chart.bar.xaxis",
                        "Live snapshot of all captured requests.")
        case .mocks:
            placeholder("server.rack",
                        "Define mock endpoints and start the server.\nCall from Xcode via http://localhost:<port>/path.")
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
