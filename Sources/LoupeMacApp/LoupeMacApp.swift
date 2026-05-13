import SwiftUI

@main
struct LoupeMacApp: App {

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(appState.client)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Clear Logs") {
                    appState.clearEntries()
                }
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
    }
}
