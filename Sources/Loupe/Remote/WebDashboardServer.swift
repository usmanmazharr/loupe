import Foundation
import Network
import Combine
import CryptoKit

actor WebDashboardServer {

    private var listener: NWListener?
    private var httpConnections: [ObjectIdentifier: NWConnection] = [:]
    private var wsConnections: [ObjectIdentifier: NWConnection] = [:]

    private var entriesCancellable: AnyCancellable?
    private var logsCancellable: AnyCancellable?
    private var eventsCancellable: AnyCancellable?

    private var knownSignatures: [UUID: WDEntrySignature] = [:]
    private var knownLogIDs: Set<UUID> = []
    private var knownEventIDs: Set<UUID> = []

    private let port: UInt16

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
        for (_, c) in httpConnections { c.cancel() }
        for (_, c) in wsConnections { c.cancel() }
        httpConnections.removeAll()
        wsConnections.removeAll()
        listener?.cancel()
        listener = nil
        knownSignatures.removeAll()
        knownLogIDs.removeAll()
        knownEventIDs.removeAll()
        print("[WebDashboard] stopped")
    }

    func getPort() -> UInt16 { port }

    // MARK: - Listener State

    private func onListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            print("[WebDashboard] listening on port \(port)")
        case .failed(let error):
            print("[WebDashboard] listener error: \(error.localizedDescription)")
            stop()
        default:
            break
        }
    }

    // MARK: - Accept

    private func accept(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        httpConnections[key] = conn
        conn.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { Task { await self?.removeAll(conn) } }
            if case .failed = state    { Task { await self?.removeAll(conn) } }
        }
        conn.start(queue: .global(qos: .utility))
        scheduleHTTPReceive(on: conn)
    }

    private func removeAll(_ conn: NWConnection) {
        let key = ObjectIdentifier(conn)
        httpConnections.removeValue(forKey: key)
        wsConnections.removeValue(forKey: key)
    }

    // MARK: - HTTP Receive

    private nonisolated func scheduleHTTPReceive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else { return }
            Task { await self.routeHTTP(data, on: conn) }
        }
    }

    // MARK: - HTTP Routing

    private func routeHTTP(_ data: Data, on conn: NWConnection) async {
        guard let raw = String(data: data, encoding: .utf8) else { return }
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return }
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return }
        let method = String(parts[0])
        let path = String(parts[1])
        let headers = parseHeaders(lines)

        // WebSocket upgrade
        if method == "GET" && path == "/ws",
           let wsKey = headers["sec-websocket-key"] {
            performWebSocketUpgrade(conn, clientKey: wsKey)
            return
        }

        // Normal HTTP
        let (status, contentType, body) = await handleAPI(method: method, path: path)
        sendHTTPResponse(conn, status: status, contentType: contentType, body: body, close: true)
    }

    private func handleAPI(method: String, path: String) async -> (String, String, Data) {
        switch (method, path) {
        case ("GET", "/"):
            return ("200 OK", "text/html; charset=utf-8", Data(WebDashboardHTML.page.utf8))

        case ("GET", "/api/entries"):
            let entries = await LogManager.shared.allEntries()
            let json = (try? JSONEncoder().encode(entries)) ?? Data("[]".utf8)
            return ("200 OK", "application/json", json)

        case ("GET", "/api/logs"):
            let logs = await LogMessageStore.shared.allMessages()
            let json = (try? JSONEncoder().encode(logs)) ?? Data("[]".utf8)
            return ("200 OK", "application/json", json)

        case ("GET", "/api/events"):
            let events = await AnalyticsEventStore.shared.allEvents()
            let json = (try? JSONEncoder().encode(events)) ?? Data("[]".utf8)
            return ("200 OK", "application/json", json)

        case ("GET", let p) where p.hasPrefix("/api/entries/"):
            let idStr = String(p.dropFirst("/api/entries/".count))
            if let uuid = UUID(uuidString: idStr) {
                let entries = await LogManager.shared.allEntries()
                if let entry = entries.first(where: { $0.effectiveID == uuid }) {
                    let json = (try? JSONEncoder().encode(entry)) ?? Data("{}".utf8)
                    return ("200 OK", "application/json", json)
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

    // MARK: - HTTP Helpers

    private func parseHeaders(_ lines: [String]) -> [String: String] {
        var h: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let idx = line.firstIndex(of: ":") {
                let k = line[line.startIndex..<idx].trimmingCharacters(in: .whitespaces).lowercased()
                let v = line[line.index(after: idx)...].trimmingCharacters(in: .whitespaces)
                h[k] = v
            }
        }
        return h
    }

    private nonisolated func sendHTTPResponse(_ conn: NWConnection, status: String, contentType: String, body: Data, close: Bool) {
        var header = "HTTP/1.1 \(status)\r\n"
        header += "Content-Type: \(contentType)\r\n"
        header += "Content-Length: \(body.count)\r\n"
        header += "Access-Control-Allow-Origin: *\r\n"
        if close { header += "Connection: close\r\n" }
        header += "\r\n"
        var payload = Data(header.utf8)
        payload.append(body)
        conn.send(content: payload, completion: .contentProcessed { _ in
            if close { conn.cancel() }
        })
    }

    // MARK: - WebSocket Upgrade

    private nonisolated func performWebSocketUpgrade(_ conn: NWConnection, clientKey: String) {
        let acceptKey = computeAcceptKey(clientKey)
        var response = "HTTP/1.1 101 Switching Protocols\r\n"
        response += "Upgrade: websocket\r\n"
        response += "Connection: Upgrade\r\n"
        response += "Sec-WebSocket-Accept: \(acceptKey)\r\n"
        response += "\r\n"
        conn.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil, let self else { return }
            Task {
                await self.didUpgradeWebSocket(conn)
            }
        })
    }

    private func didUpgradeWebSocket(_ conn: NWConnection) async {
        let key = ObjectIdentifier(conn)
        wsConnections[key] = conn
        print("[WebDashboard] WebSocket connected (\(wsConnections.count) total)")

        // Send current state
        await sendWSSnapshot(to: conn)

        // Start reading WS frames
        scheduleWSReceive(on: conn)
    }

    private nonisolated func computeAcceptKey(_ clientKey: String) -> String {
        let magic = clientKey + "258EAFA5-E914-47DA-95CA-5AB5AA86BE78"
        let hash = Insecure.SHA1.hash(data: Data(magic.utf8))
        return Data(hash).base64EncodedString()
    }

    // MARK: - WebSocket Send / Receive

    private func sendWSSnapshot(to conn: NWConnection) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let entries = await LogManager.shared.allEntries()
        if !entries.isEmpty, let json = try? encoder.encode(entries) {
            sendWSJSON(type: "entries", json: json, to: conn)
        }

        let logs = await LogMessageStore.shared.allMessages()
        if !logs.isEmpty, let json = try? encoder.encode(logs) {
            sendWSJSON(type: "logs", json: json, to: conn)
        }

        let events = await AnalyticsEventStore.shared.allEvents()
        if !events.isEmpty, let json = try? encoder.encode(events) {
            sendWSJSON(type: "events", json: json, to: conn)
        }
    }

    private nonisolated func sendWSJSON(type: String, json: Data, to conn: NWConnection) {
        guard let payload = String(data: json, encoding: .utf8) else { return }
        let msg = "{\"type\":\"\(type)\",\"payload\":\(payload)}"
        sendWSTextFrame(msg, to: conn)
    }

    private nonisolated func sendWSTextFrame(_ text: String, to conn: NWConnection) {
        let payload = Data(text.utf8)
        var frame = Data()
        frame.append(0x81) // FIN + text
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count <= 65535 {
            frame.append(126)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((payload.count >> (i * 8)) & 0xFF))
            }
        }
        frame.append(payload)
        conn.send(content: frame, completion: .idempotent)
    }

    private nonisolated func scheduleWSReceive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 2, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data {
                let decoded = Self.decodeWSFrame(data)
                if decoded == "ping" {
                    self.sendWSTextFrame("pong", to: conn)
                }
            }
            if error == nil, !isComplete {
                self.scheduleWSReceive(on: conn)
            }
        }
    }

    private static func decodeWSFrame(_ data: Data) -> String? {
        guard data.count >= 2 else { return nil }
        let masked = (data[1] & 0x80) != 0
        var payloadLen = Int(data[1] & 0x7F)
        var offset = 2
        if payloadLen == 126 {
            guard data.count >= 4 else { return nil }
            payloadLen = Int(data[2]) << 8 | Int(data[3])
            offset = 4
        } else if payloadLen == 127 {
            guard data.count >= 10 else { return nil }
            payloadLen = 0
            for i in 0..<8 { payloadLen = (payloadLen << 8) | Int(data[2 + i]) }
            offset = 10
        }
        var maskKey: [UInt8] = []
        if masked {
            guard data.count >= offset + 4 else { return nil }
            maskKey = [data[offset], data[offset+1], data[offset+2], data[offset+3]]
            offset += 4
        }
        guard data.count >= offset + payloadLen else { return nil }
        var payload = Array(data[offset..<(offset + payloadLen)])
        if masked {
            for i in 0..<payload.count { payload[i] ^= maskKey[i % 4] }
        }
        return String(bytes: payload, encoding: .utf8)
    }

    // MARK: - Broadcasting

    private func broadcastEntryChanges(_ entries: [NetworkEntry]) {
        guard !wsConnections.isEmpty else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if entries.isEmpty {
            knownSignatures.removeAll()
            broadcastWSText("{\"type\":\"clear\",\"payload\":\"\"}")
            return
        }
        for entry in entries {
            let key = entry.effectiveID
            let sig = WDEntrySignature(entry)
            if knownSignatures[key] != sig {
                knownSignatures[key] = sig
                if let json = try? encoder.encode(entry),
                   let payload = String(data: json, encoding: .utf8) {
                    broadcastWSText("{\"type\":\"entry\",\"payload\":\(payload)}")
                }
            }
        }
    }

    private func broadcastLogChanges(_ messages: [LogMessage]) {
        guard !wsConnections.isEmpty else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for msg in messages where !knownLogIDs.contains(msg.id) {
            knownLogIDs.insert(msg.id)
            if let json = try? encoder.encode(msg),
               let payload = String(data: json, encoding: .utf8) {
                broadcastWSText("{\"type\":\"log\",\"payload\":\(payload)}")
            }
        }
    }

    private func broadcastEventChanges(_ events: [AnalyticsEvent]) {
        guard !wsConnections.isEmpty else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        for event in events where !knownEventIDs.contains(event.id) {
            knownEventIDs.insert(event.id)
            if let json = try? encoder.encode(event),
               let payload = String(data: json, encoding: .utf8) {
                broadcastWSText("{\"type\":\"event\",\"payload\":\(payload)}")
            }
        }
    }

    private func broadcastWSText(_ text: String) {
        for (_, conn) in wsConnections {
            sendWSTextFrame(text, to: conn)
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
