import Foundation
import Network

// MARK: - Discovered Device

struct DiscoveredDevice: Identifiable, Equatable {
    let id:       String          // Bonjour service name (stable per device)
    let endpoint: NWEndpoint
    var info:     MacDeviceInfo?  // filled in after hello handshake

    var displayName: String {
        info.map { "\($0.deviceName) — \($0.appName)" } ?? id
    }

    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool { lhs.id == rhs.id }
}

// MARK: - RemoteClient

/// Discovers iOS devices advertising `_loupe._tcp` on the local network and manages
/// a single active connection.  All callbacks fire on the main actor.
@MainActor
final class RemoteClient: ObservableObject {

    // MARK: Public state

    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedDevice:   DiscoveredDevice?
    @Published var isConnecting:      Bool = false
    @Published var connectionError:   String?

    // Called by AppState when messages arrive.
    var onHello:           ((MacDeviceInfo) -> Void)?
    var onBatch:           (([MacNetworkEntry]) -> Void)?
    var onEntry:           ((MacNetworkEntry) -> Void)?
    var onClear:           (() -> Void)?
    var onLogMessage:      ((MacLogMessage) -> Void)?
    var onLogBatch:        (([MacLogMessage]) -> Void)?
    var onAnalyticsEvent:  ((MacAnalyticsEvent) -> Void)?
    var onAnalyticsBatch:  (([MacAnalyticsEvent]) -> Void)?

    // MARK: Private

    private var browser:    NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private let decoder = JSONDecoder()

    // MARK: - Browsing

    func startBrowsing() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: "_loupe._tcp", domain: "local."),
                                using: NWParameters())
        browser.stateUpdateHandler = { [weak self] state in
            print("[RemoteClient] browser state: \(state)")
            DispatchQueue.main.async { self?.onBrowserState(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            print("[RemoteClient] found \(results.count) result(s): \(results.map { "\($0.endpoint)" })")
            DispatchQueue.main.async { self?.updateDevices(from: results) }
        }
        browser.start(queue: .global(qos: .utility))
        self.browser = browser
        print("[RemoteClient] started browsing for _loupe._tcp")
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    // MARK: - Connecting

    func connect(to device: DiscoveredDevice) {
        disconnect()
        isConnecting    = true
        connectionError = nil
        connectedDevice = nil

        let params = NWParameters.tcp
        params.includePeerToPeer = true
        let conn = NWConnection(to: device.endpoint, using: params)

        conn.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in self?.onConnectionState(state, device: device) }
        }
        conn.start(queue: .global(qos: .utility))
        connection = conn
        scheduleReceive(on: conn)
    }

    func disconnect() {
        connection?.cancel()
        connection     = nil
        connectedDevice = nil
        receiveBuffer  = Data()
        isConnecting   = false
    }

    func sendClear() {
        send(envelope: MacRemoteEnvelope(type: .requestClear, payload: nil))
    }

    func sendSetPinned(id: UUID, pinned: Bool) {
        let payload = try? JSONEncoder().encode(MacSetPinnedPayload(id: id, pinned: pinned))
        send(envelope: MacRemoteEnvelope(type: .setPinned, payload: payload))
    }

    private func send(envelope: MacRemoteEnvelope) {
        guard let conn = connection else { return }
        guard let json = try? JSONEncoder().encode(envelope) else { return }
        var length = UInt32(json.count).bigEndian
        var frame = Data(bytes: &length, count: 4)
        frame.append(json)
        conn.send(content: frame, completion: .idempotent)
    }

    // MARK: - Browser callbacks

    private func onBrowserState(_ state: NWBrowser.State) {
        if case .failed(let e) = state {
            print("Browser failed: \(e.localizedDescription)")
        }
    }

    private func updateDevices(from results: Set<NWBrowser.Result>) {
        let incoming = results.compactMap { result -> DiscoveredDevice? in
            guard case .service(let name, _, _, _) = result.endpoint else { return nil }
            return DiscoveredDevice(id: name, endpoint: result.endpoint)
        }
        // Preserve existing info for already-known devices.
        discoveredDevices = incoming.map { new in
            if let existing = discoveredDevices.first(where: { $0.id == new.id }) { return existing }
            return new
        }
    }

    // MARK: - Connection callbacks

    private func onConnectionState(_ state: NWConnection.State, device: DiscoveredDevice) {
        switch state {
        case .ready:
            isConnecting    = false
            connectedDevice = device
            connectionError = nil
            print("Connected to \(device.displayName)")

        case .failed(let error):
            isConnecting    = false
            connectedDevice = nil
            connectionError = error.localizedDescription
            print("Connection failed: \(error.localizedDescription)")

        case .cancelled:
            isConnecting    = false
            connectedDevice = nil

        default:
            break
        }
    }

    // MARK: - Receiving

    private func scheduleReceive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let data { self.receiveBuffer.append(data) }
                self.drainBuffer()
                if let error {
                    print("Receive error: \(error.localizedDescription)")
                } else if !isComplete {
                    self.scheduleReceive(on: conn)
                }
            }
        }
    }

    private func drainBuffer() {
        guard !receiveBuffer.isEmpty else { return }
        do {
            while receiveBuffer.count >= 4 {
                let si = receiveBuffer.startIndex
                let length = Int(
                    (UInt32(receiveBuffer[si])     << 24) |
                    (UInt32(receiveBuffer[si + 1]) << 16) |
                    (UInt32(receiveBuffer[si + 2]) << 8)  |
                     UInt32(receiveBuffer[si + 3])
                )
                guard length > 0, length < 10_000_000 else {
                    receiveBuffer.removeAll()
                    break
                }
                guard receiveBuffer.count >= 4 + length else { break }
                // Copy to a fresh Data to avoid slice index issues.
                let json = Data(receiveBuffer[si + 4 ..< si + 4 + length])
                receiveBuffer.removeFirst(4 + length)
                let envelope = try decoder.decode(MacRemoteEnvelope.self, from: json)
                handle(envelope)
            }
        } catch {
            print("Decode error: \(error.localizedDescription)")
        }
    }

    private func handle(_ envelope: MacRemoteEnvelope) {
        switch envelope.type {
        case .hello:
            guard let payload = envelope.payload,
                  let info = try? decoder.decode(MacDeviceInfo.self, from: payload) else { return }
            // Attach real device name to the discovered device entry.
            if let idx = discoveredDevices.firstIndex(where: { $0.endpoint == connectedDevice?.endpoint }) {
                discoveredDevices[idx].info = info
            }
            connectedDevice?.info = info
            onHello?(info)

        case .batch:
            guard let payload = envelope.payload,
                  let entries = try? decoder.decode([MacNetworkEntry].self, from: payload) else { return }
            onBatch?(entries)

        case .entry:
            guard let payload = envelope.payload,
                  let entry = try? decoder.decode(MacNetworkEntry.self, from: payload) else { return }
            onEntry?(entry)

        case .clear:
            onClear?()

        case .logMessage:
            guard let payload = envelope.payload,
                  let msg = try? decoder.decode(MacLogMessage.self, from: payload) else { return }
            onLogMessage?(msg)

        case .logBatch:
            guard let payload = envelope.payload,
                  let msgs = try? decoder.decode([MacLogMessage].self, from: payload) else { return }
            onLogBatch?(msgs)

        case .analyticsEvent:
            guard let payload = envelope.payload,
                  let event = try? decoder.decode(MacAnalyticsEvent.self, from: payload) else { return }
            onAnalyticsEvent?(event)

        case .analyticsBatch:
            guard let payload = envelope.payload,
                  let events = try? decoder.decode([MacAnalyticsEvent].self, from: payload) else { return }
            onAnalyticsBatch?(events)

        case .requestClear, .setPinned:
            // Outbound-only on macOS — never received.
            break
        }
    }
}
