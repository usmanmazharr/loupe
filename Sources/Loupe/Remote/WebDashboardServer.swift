import Foundation
import Network
import Combine

actor WebDashboardServer {

    private var listener: NWListener?
    private var sseConnections: [ObjectIdentifier: NWConnection] = [:]

    private var entriesCancellable: AnyCancellable?
    private var logsCancellable: AnyCancellable?
    private var eventsCancellable: AnyCancellable?

    private var knownSignatures: [UUID: WDEntrySignature] = [:]
    private var knownLogIDs: Set<UUID> = []
    private var knownEventIDs: Set<UUID> = []

    private let port: UInt16
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(port: UInt16 = 9800) {
        self.port = port
    }

    // MARK: - Lifecycle

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            l.stateUpdateHandler = { [weak self] state in
                Task { await self?.onListenerState(state) }
            }
            l.newConnectionHandler = { [weak self] conn in
                Task { await self?.accept(conn) }
            }
            l.start(queue: .global(qos: .utility))
            self.listener = l

            entriesCancellable = LogManager.shared.entriesPublisher
                .dropFirst()
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] entries in
                    Task { await self?.broadcastEntryChanges(entries) }
                }

            logsCancellable = LogMessageStore.shared.messagesPublisher
                .dropFirst()
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] messages in
                    Task { await self?.broadcastLogChanges(messages) }
                }

            eventsCancellable = AnalyticsEventStore.shared.eventsPublisher
                .dropFirst()
                .receive(on: DispatchQueue.global(qos: .utility))
                .sink { [weak self] events in
                    Task { await self?.broadcastEventChanges(events) }
                }

            print("[WebDashboard] started on port \(port) — open http://<device-ip>:\(port)")
        } catch {
            print("[WebDashboard] failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        entriesCancellable = nil
        logsCancellable = nil
        eventsCancellable = nil
        for (_, c) in sseConnections { c.cancel() }
        sseConnections.removeAll()
        listener?.cancel()
        listener = nil
        knownSignatures.removeAll()
        knownLogIDs.removeAll()
        knownEventIDs.removeAll()
        print("[WebDashboard] stopped")
    }

    func getPort() -> UInt16 { port }

    // MARK: - Listener

    private func onListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:  print("[WebDashboard] listening on port \(port)")
        case .failed(let e): print("[WebDashboard] error: \(e.localizedDescription)"); stop()
        default: break
        }
    }

    // MARK: - Accept

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { Task { await self?.removeSSE(conn) } }
            if case .failed    = state { Task { await self?.removeSSE(conn) } }
        }
        conn.start(queue: .global(qos: .utility))
        readRequest(on: conn)
    }

    private func removeSSE(_ conn: NWConnection) {
        sseConnections.removeValue(forKey: ObjectIdentifier(conn))
    }

    // MARK: - Read HTTP Request

    private nonisolated func readRequest(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else { return }
            Task { await self.route(data, on: conn) }
        }
    }

    // MARK: - Route

    private func route(_ data: Data, on conn: NWConnection) async {
        guard let raw = String(data: data, encoding: .utf8) else { return }
        let lines = raw.components(separatedBy: "\r\n")
        guard let first = lines.first else { return }
        let parts = first.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return }
        let method = String(parts[0])
        let path = String(parts[1])

        // SSE endpoint — keep connection alive
        if method == "GET" && path == "/events" {
            await startSSE(on: conn)
            return
        }

        // Normal HTTP
        let (status, ctype, body) = await handleAPI(method: method, path: path)
        sendHTTP(conn, status: status, contentType: ctype, body: body)
    }

    private func handleAPI(method: String, path: String) async -> (String, String, Data) {
        switch (method, path) {
        case ("GET", "/"):
            return ("200 OK", "text/html; charset=utf-8", Data(WebDashboardHTML.page.utf8))
        case ("GET", "/api/entries"):
            let entries = await LogManager.shared.allEntries()
            return ("200 OK", "application/json", (try? encoder.encode(entries)) ?? Data("[]".utf8))
        case ("GET", "/api/logs"):
            let logs = await LogMessageStore.shared.allMessages()
            return ("200 OK", "application/json", (try? encoder.encode(logs)) ?? Data("[]".utf8))
        case ("GET", "/api/events"):
            let events = await AnalyticsEventStore.shared.allEvents()
            return ("200 OK", "application/json", (try? encoder.encode(events)) ?? Data("[]".utf8))
        case ("GET", let p) where p.hasPrefix("/api/entries/"):
            let idStr = String(p.dropFirst("/api/entries/".count))
            if let uuid = UUID(uuidString: idStr) {
                let entries = await LogManager.shared.allEntries()
                if let entry = entries.first(where: { $0.effectiveID == uuid }) {
                    return ("200 OK", "application/json", (try? encoder.encode(entry)) ?? Data("{}".utf8))
                }
                return ("404 Not Found", "application/json", Data("{\"error\":\"not found\"}".utf8))
            }
            return ("400 Bad Request", "application/json", Data("{\"error\":\"invalid id\"}".utf8))
        case ("DELETE", "/api/entries"):
            await LogManager.shared.clearAll(keepingPinned: false)
            return ("200 OK", "application/json", Data("{\"ok\":true}".utf8))
        default:
            return ("404 Not Found", "text/plain", Data("Not Found".utf8))
        }
    }

    // MARK: - HTTP Response

    private nonisolated func sendHTTP(_ conn: NWConnection, status: String, contentType: String, body: Data) {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var payload = Data(header.utf8)
        payload.append(body)
        conn.send(content: payload, completion: .contentProcessed { _ in conn.cancel() })
    }

    // MARK: - SSE (Server-Sent Events)

    private func startSSE(on conn: NWConnection) async {
        let header = "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nAccess-Control-Allow-Origin: *\r\nConnection: keep-alive\r\n\r\n"
        conn.send(content: Data(header.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil, let self else { return }
            Task { await self.didStartSSE(conn) }
        })
    }

    private func didStartSSE(_ conn: NWConnection) async {
        let key = ObjectIdentifier(conn)
        sseConnections[key] = conn
        print("[WebDashboard] SSE client connected (\(sseConnections.count) total)")

        // Send current snapshot
        let entries = await LogManager.shared.allEntries()
        if !entries.isEmpty, let json = try? encoder.encode(entries) {
            sendSSE(type: "entries", json: json, to: conn)
        }
        let logs = await LogMessageStore.shared.allMessages()
        if !logs.isEmpty, let json = try? encoder.encode(logs) {
            sendSSE(type: "logs", json: json, to: conn)
        }
        let events = await AnalyticsEventStore.shared.allEvents()
        if !events.isEmpty, let json = try? encoder.encode(events) {
            sendSSE(type: "events", json: json, to: conn)
        }
    }

    private nonisolated func sendSSE(type: String, json: Data, to conn: NWConnection) {
        guard let payload = String(data: json, encoding: .utf8) else { return }
        let msg = "event: \(type)\ndata: \(payload)\n\n"
        conn.send(content: Data(msg.utf8), completion: .idempotent)
    }

    // MARK: - Broadcasting

    private func broadcastEntryChanges(_ entries: [NetworkEntry]) {
        guard !sseConnections.isEmpty else { return }
        if entries.isEmpty {
            knownSignatures.removeAll()
            broadcastSSEText("event: clear\ndata: {}\n\n")
            return
        }
        for entry in entries {
            let eid = entry.effectiveID
            let sig = WDEntrySignature(entry)
            if knownSignatures[eid] != sig {
                knownSignatures[eid] = sig
                if let json = try? encoder.encode(entry) {
                    for (_, conn) in sseConnections { sendSSE(type: "entry", json: json, to: conn) }
                }
            }
        }
    }

    private func broadcastLogChanges(_ messages: [LogMessage]) {
        guard !sseConnections.isEmpty else { return }
        for msg in messages where !knownLogIDs.contains(msg.id) {
            knownLogIDs.insert(msg.id)
            if let json = try? encoder.encode(msg) {
                for (_, conn) in sseConnections { sendSSE(type: "log", json: json, to: conn) }
            }
        }
    }

    private func broadcastEventChanges(_ events: [AnalyticsEvent]) {
        guard !sseConnections.isEmpty else { return }
        for event in events where !knownEventIDs.contains(event.id) {
            knownEventIDs.insert(event.id)
            if let json = try? encoder.encode(event) {
                for (_, conn) in sseConnections { sendSSE(type: "event", json: json, to: conn) }
            }
        }
    }

    private func broadcastSSEText(_ text: String) {
        let data = Data(text.utf8)
        for (_, conn) in sseConnections {
            conn.send(content: data, completion: .idempotent)
        }
    }
}

// MARK: - Supporting Types

private struct WDEntrySignature: Equatable {
    let status: NetworkEntryStatus
    let statusCode: Int?
    let isPinned: Bool
    init(_ entry: NetworkEntry) {
        status = entry.status
        statusCode = entry.statusCode
        isPinned = entry.isPinned
    }
}
