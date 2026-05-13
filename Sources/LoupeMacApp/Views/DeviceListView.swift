import SwiftUI

/// Sidebar: lists discovered Bonjour devices and the current connection status.
struct DeviceListView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var client: RemoteClient
    @State private var hovered: String?

    var body: some View {
        List(selection: Binding(
            get: { appState.viewMode },
            set: { if let v = $0 { appState.viewMode = v } }
        )) {
            Section("View") {
                ForEach(AppState.ViewMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.systemImage)
                        .tag(mode)
                }
            }

            Section("Discovered Devices") {
                if client.discoveredDevices.isEmpty {
                    Text("Scanning…")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(client.discoveredDevices) { device in
                        DeviceRow(
                            device:       device,
                            isActive:     client.connectedDevice?.id == device.id,
                            isConnecting: client.isConnecting
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { client.connect(to: device) }
                    }
                }
            }

            if let error = client.connectionError {
                Section("Error") {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .listStyle(.sidebar)
        .onAppear { client.startBrowsing() }
    }
}

// MARK: - Device Row

private struct DeviceRow: View {

    let device:       DiscoveredDevice
    let isActive:     Bool
    let isConnecting: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isActive ? "iphone.and.arrow.forward" : "iphone")
                .foregroundStyle(isActive ? .blue : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.info?.deviceName ?? device.id)
                    .font(.callout.weight(.medium))
                if let info = device.info {
                    Text("\(info.appName) \(info.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isActive {
                if isConnecting {
                    ProgressView().scaleEffect(0.6)
                } else {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
