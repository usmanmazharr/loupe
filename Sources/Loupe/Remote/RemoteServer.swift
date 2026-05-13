import Foundation
import Network
import Combine

// MARK: - RemoteServer

/// Bonjour-advertised TCP server that streams NetworkEntry events to any connected
/// macOS LoupeMacApp client on the same local network.
///
/// **iOS app Info.plist requirements** (add once, to your app target):
///   NSLocalNetworkUsageDescription  →  "Loupe streams logs to the macOS companion app."
///   NSBonjourServices               →  _loupe._tcp.
///
actor RemoteServer {

    // MARK: State

    private var listener:    NWListener?
    private var connections: [NWConnection] = []
    private var entriesCancellable:  AnyCancellable?
    private var logsCancellable:     AnyCancellable?
    private var eventsCancellable:   AnyCancellable?

    /// Tracks last-seen (status, statusCode, isPinned) per entry so we only
    /// broadcast real changes.
    private var knownSignatures: [UUID: EntrySignature] = [:]
    /// Highest log message id we've already broadcast.
    private var knownLogIDs: Set<UUID> = []
    /// Highest analytics event id we've already broadcast.
    private var knownEventIDs: Set<UUID> = []

    /// Per-connection receive buffers for inbound (macOS→iOS) messages.
    private var receiveBuffers: [ObjectIdentifier: Data] = [:]

    private let deviceInfo = DeviceInfo()

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        do {
            let params   = NWParameters.tcp
            let listener = try NWListener(using: params)
            // Advertise via Bonjour so the macOS app can discover us without an IP address.
            listener.service = NWListener.Service(type: "_loupe._tcp")

            listener.stateUpdateHandler = { [weak self] state in
                Task { await self?.onListenerState(state) }
            }
            listener.newConnectionHandler = { [weak self] conn in
                Task { await self?.accept(conn) }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener

            // Subscribe to log manager — fires whenever any entry changes.
            entriesCancellable = LogManager.shared.entriesPublisher
                .dropFirst()
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] entries in
                    Task { await self?.broadcastChanges(in: entries) }
                }

            // Subscribe to console log messages.
            logsCancellable = LogMessageStore.shared.messagesPublisher
                .dropFirst()
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] messages in
                    Task { await self?.broadcastLogChanges(in: messages) }
                }

            // Subscribe to analytics events.
            eventsCancellable = AnalyticsEventStore.shared.eventsPublisher
                .dropFirst()
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] events in
                    Task { await self?.broadcastEventChanges(in: events) }
                }

            print("[RemoteServer] started, advertising _loupe._tcp")
        } catch {
            print("[RemoteServer] failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        entriesCancellable = nil
        logsCancellable    = nil
        eventsCancellable  = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
        knownSignatures.removeAll()
        knownLogIDs.removeAll()
        knownEventIDs.removeAll()
        print("[RemoteServer] stopped")
    }

    // MARK: - Listener state

    private func onListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("[RemoteServer] listening on port \(self.listener?.port?.rawValue ?? 0)")
        case .failed(let error):
            print("[RemoteServer] listener error: \(error.localizedDescription)")
            stop()
        default:
            break
        }
    }

    // MARK: - Connection handling

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                Task { await self?.remove(connection) }
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .utility))
        scheduleReceive(on: connection)

        Task {
            send(RemoteEnvelope(type: .hello,
                                payload: try? JSONEncoder().encode(deviceInfo)),
                 to: connection)

            // Send only the 20 most recent entries to avoid overwhelming the client.
            let allEntries = await LogManager.shared.allEntries()
            let entries = Array(allEntries.prefix(20))
            if !entries.isEmpty {
                send(RemoteEnvelope(type: .batch,
                                    payload: try? JSONEncoder().encode(entries)),
                     to: connection)
                for e in entries { knownSignatures[e.effectiveID] = EntrySignature(e) }
            }

            // Send recent console messages and analytics events too.
            let messages = await LogMessageStore.shared.allMessages().suffix(100)
            if !messages.isEmpty {
                send(RemoteEnvelope(type: .logBatch,
                                    payload: try? JSONEncoder().encode(Array(messages))),
                     to: connection)
                for m in messages { knownLogIDs.insert(m.id) }
            }
            let events = await AnalyticsEventStore.shared.allEvents().suffix(200)
            if !events.isEmpty {
                send(RemoteEnvelope(type: .analyticsBatch,
                                    payload: try? JSONEncoder().encode(Array(events))),
                     to: connection)
                for e in events { knownEventIDs.insert(e.id) }
            }
        }

        print("[RemoteServer] client connected (\(self.connections.count) total)")
    }

    private func remove(_ connection: NWConnection) {
        receiveBuffers.removeValue(forKey: ObjectIdentifier(connection))
        connections.removeAll { $0 === connection }
        print("[RemoteServer] client disconnected (\(self.connections.count) remaining)")
    }

    // MARK: - Receiving (macOS → iOS commands)

    private func scheduleReceive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self else { return }
                if let data {
                    let key = ObjectIdentifier(conn)
                    var buf = self.receiveBuffers[key] ?? Data()
                    buf.append(data)
                    self.receiveBuffers[key] = buf
                    await self.drainBuffer(for: conn)
                }
                if error == nil, !isComplete {
                    self.scheduleReceive(on: conn)
                }
            }
        }
    }

    private func drainBuffer(for conn: NWConnection) async {
        let key = ObjectIdentifier(conn)
        guard var buf = receiveBuffers[key] else { return }
        while buf.count >= 4 {
            let si = buf.startIndex
            let length = Int(
                (UInt32(buf[si])     << 24) |
                (UInt32(buf[si + 1]) << 16) |
                (UInt32(buf[si + 2]) << 8)  |
                 UInt32(buf[si + 3])
            )
            guard length > 0, length < 10_000_000 else { buf.removeAll(); break }
            guard buf.count >= 4 + length else { break }
            let json = Data(buf[si + 4 ..< si + 4 + length])
            buf.removeFirst(4 + length)
            if let envelope = try? JSONDecoder().decode(RemoteEnvelope.self, from: json) {
                await handleInbound(envelope)
            }
        }
        receiveBuffers[key] = buf
    }

    private func handleInbound(_ envelope: RemoteEnvelope) async {
        switch envelope.type {
        case .requestClear:
            print("[RemoteServer] received requestClear — wiping log store")
            await LogManager.shared.clearAll()
        case .setPinned:
            guard let payload = envelope.payload,
                  let cmd = try? JSONDecoder().decode(SetPinnedPayload.self, from: payload)
            else { return }
            await LogManager.shared.setPinned(cmd.pinned, id: cmd.id)
        default:
            break
        }
    }

    // MARK: - Broadcasting

    private func broadcastChanges(in entries: [NetworkEntry]) {
        guard !connections.isEmpty else { return }

        // Empty snapshot means clearAll() was called.
        if entries.isEmpty {
            knownSignatures.removeAll()
            broadcast(RemoteEnvelope(type: .clear))
            return
        }

        for entry in entries {
            let key = entry.effectiveID
            let sig = EntrySignature(entry)
            if knownSignatures[key] != sig {
                knownSignatures[key] = sig
                send(entry)
            }
        }
    }

    private func send(_ entry: NetworkEntry) {
        let envelope = RemoteEnvelope(
            type:    .entry,
            payload: try? JSONEncoder().encode(entry)
        )
        broadcast(envelope)
    }

    private func broadcastLogChanges(in messages: [LogMessage]) {
        guard !connections.isEmpty else { return }
        for msg in messages where !knownLogIDs.contains(msg.id) {
            knownLogIDs.insert(msg.id)
            let envelope = RemoteEnvelope(
                type:    .logMessage,
                payload: try? JSONEncoder().encode(msg)
            )
            broadcast(envelope)
        }
    }

    private func broadcastEventChanges(in events: [AnalyticsEvent]) {
        guard !connections.isEmpty else { return }
        for event in events where !knownEventIDs.contains(event.id) {
            knownEventIDs.insert(event.id)
            let envelope = RemoteEnvelope(
                type:    .analyticsEvent,
                payload: try? JSONEncoder().encode(event)
            )
            broadcast(envelope)
        }
    }

    private func broadcast(_ envelope: RemoteEnvelope) {
        guard let data = try? RemoteFraming.encode(envelope) else { return }
        connections.forEach { $0.send(content: data, completion: .idempotent) }
    }

    private func send(_ envelope: RemoteEnvelope, to connection: NWConnection) {
        guard let data = try? RemoteFraming.encode(envelope) else { return }
        connection.send(content: data, completion: .idempotent)
    }
}

// MARK: - Entry Signature

/// Lightweight value used to detect when an entry needs to be re-broadcast.
private struct EntrySignature: Equatable {
    let status:     NetworkEntryStatus
    let statusCode: Int?
    let isPinned:   Bool

    init(_ entry: NetworkEntry) {
        status     = entry.status
        statusCode = entry.statusCode
        isPinned   = entry.isPinned
    }
}
