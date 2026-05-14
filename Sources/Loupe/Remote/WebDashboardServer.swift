import Foundation
import Network
import Combine
import CryptoKit

actor WebDashboardServer {

    private var listener: NWListener?
    private var connections: [ObjectIdentifier: NWConnection] = [:]
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
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { [weak self] state in
                Task { await self?.onListenerState(state) }
            }
            listener.newConnectionHandler = { [weak self] conn in
                Task { await self?.accept(conn) }
            }
            listener.start(queue: .global(qos: .utility))
            self.listener = listener

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

            print("[WebDashboard] started on port \(port) — open http://<device-ip>:\(port) in any browser")
        } catch {
            print("[WebDashboard] failed to start: \(error.localizedDescription)")
        }
    }

    func stop() {
        entriesCancellable = nil
        logsCancellable = nil
        eventsCancellable = nil
        for (_, conn) in connections { conn.cancel() }
        for (_, conn) in wsConnections { conn.cancel() }
        connections.removeAll()
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

    // MARK: - Connection Handling

    private func accept(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections[key] = connection
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .cancelled, .failed:
                Task { await self?.remove(connection) }
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .utility))
        receiveHTTP(on: connection)
    }

    private func remove(_ connection: NWConnection) {
        let key = ObjectIdentifier(connection)
        connections.removeValue(forKey: key)
        wsConnections.removeValue(forKey: key)
    }

    // MARK: - HTTP Receive

    private func receiveHTTP(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self, let data else { return }
                let upgraded = await self.handleHTTPRequest(data, on: conn)
                if !upgraded, error == nil, !isComplete {
                    await self.receiveHTTP(on: conn)
                }
            }
        }
    }

    // MARK: - HTTP Request Routing

    /// Returns `true` if the connection was upgraded to WebSocket.
    @discardableResult
    private func handleHTTPRequest(_ data: Data, on conn: NWConnection) async -> Bool {
        guard let raw = String(data: data, encoding: .utf8) else { return false }
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return false }
        let parts = requestLine.split(separator: " ", maxSplits: 2)
        guard parts.count >= 2 else { return false }
        let method = String(parts[0])
        let path = String(parts[1])

        let headers = parseHeaders(lines)

        if method == "GET" && path == "/ws" {
            if let wsKey = headers["sec-websocket-key"] {
                await upgradeToWebSocket(conn, key: wsKey)
                return true
            }
        }

        let (status, contentType, body): (String, String, Data)

        switch (method, path) {
        case ("GET", "/"):
            (status, contentType, body) = ("200 OK", "text/html; charset=utf-8", Data(WebDashboardHTML.page.utf8))

        case ("GET", "/api/entries"):
            let entries = await LogManager.shared.allEntries()
            let json = (try? JSONEncoder().encode(entries)) ?? Data("[]".utf8)
            (status, contentType, body) = ("200 OK", "application/json", json)

        case ("GET", "/api/logs"):
            let logs = await LogMessageStore.shared.allMessages()
            let json = (try? JSONEncoder().encode(logs)) ?? Data("[]".utf8)
            (status, contentType, body) = ("200 OK", "application/json", json)

        case ("GET", "/api/events"):
            let events = await AnalyticsEventStore.shared.allEvents()
            let json = (try? JSONEncoder().encode(events)) ?? Data("[]".utf8)
            (status, contentType, body) = ("200 OK", "application/json", json)

        case ("GET", let p) where p.hasPrefix("/api/entries/"):
            let idStr = String(p.dropFirst("/api/entries/".count))
            if let uuid = UUID(uuidString: idStr) {
                let entries = await LogManager.shared.allEntries()
                if let entry = entries.first(where: { $0.effectiveID == uuid }) {
                    let json = (try? JSONEncoder().encode(entry)) ?? Data("{}".utf8)
                    (status, contentType, body) = ("200 OK", "application/json", json)
                } else {
                    (status, contentType, body) = ("404 Not Found", "application/json", Data("{\"error\":\"not found\"}".utf8))
                }
            } else {
                (status, contentType, body) = ("400 Bad Request", "application/json", Data("{\"error\":\"invalid id\"}".utf8))
            }

        case ("DELETE", "/api/entries"):
            await LogManager.shared.clearAll(keepingPinned: false)
            (status, contentType, body) = ("200 OK", "application/json", Data("{\"ok\":true}".utf8))

        default:
            (status, contentType, body) = ("404 Not Found", "text/plain", Data("Not Found".utf8))
        }

        let response = buildHTTPResponse(status: status, contentType: contentType, body: body)
        conn.send(content: response, completion: .contentProcessed { _ in
            conn.cancel()
        })
        return false
    }

    private func parseHeaders(_ lines: [String]) -> [String: String] {
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            if line.isEmpty { break }
            if let colonIdx = line.firstIndex(of: ":") {
                let key = line[line.startIndex..<colonIdx].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)
                headers[key] = value
            }
        }
        return headers
    }

    private func buildHTTPResponse(status: String, contentType: String, body: Data) -> Data {
        let header = """
        HTTP/1.1 \(status)\r
        Content-Type: \(contentType)\r
        Content-Length: \(body.count)\r
        Access-Control-Allow-Origin: *\r
        Connection: close\r
        \r\n
        """
        var response = Data(header.utf8)
        response.append(body)
        return response
    }

    // MARK: - WebSocket Upgrade

    private func upgradeToWebSocket(_ conn: NWConnection, key: String) async {
        let acceptKey = computeWebSocketAccept(key)
        let response = """
        HTTP/1.1 101 Switching Protocols\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: \(acceptKey)\r
        \r\n
        """
        conn.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
            Task { [weak self] in
                guard let self else { return }
                let key = ObjectIdentifier(conn)
                await self.addWSConnection(key: key, conn: conn)
                await self.sendInitialWSData(conn)
                await self.receiveWSFrames(on: conn)
            }
        })
    }

    private func addWSConnection(key: ObjectIdentifier, conn: NWConnection) {
        wsConnections[key] = conn
        print("[WebDashboard] WebSocket client connected (\(wsConnections.count) total)")
    }

    private func computeWebSocketAccept(_ key: String) -> String {
        let magic = key + "258EAFA5-E914-47DA-95CA-5AB5AA86BE78"
        let hash = Insecure.SHA1.hash(data: Data(magic.utf8))
        return Data(hash).base64EncodedString()
    }

    // MARK: - WebSocket Frames

    private func sendInitialWSData(_ conn: NWConnection) async {
        let entries = await LogManager.shared.allEntries()
        if !entries.isEmpty, let json = try? JSONEncoder().encode(entries) {
            let msg = WSDashboardMessage(type: "entries", payload: String(data: json, encoding: .utf8) ?? "[]")
            if let data = try? JSONEncoder().encode(msg) {
                sendWSFrame(String(data: data, encoding: .utf8) ?? "", to: conn)
            }
        }

        let logs = await LogMessageStore.shared.allMessages()
        if !logs.isEmpty, let json = try? JSONEncoder().encode(logs) {
            let msg = WSDashboardMessage(type: "logs", payload: String(data: json, encoding: .utf8) ?? "[]")
            if let data = try? JSONEncoder().encode(msg) {
                sendWSFrame(String(data: data, encoding: .utf8) ?? "", to: conn)
            }
        }

        let events = await AnalyticsEventStore.shared.allEvents()
        if !events.isEmpty, let json = try? JSONEncoder().encode(events) {
            let msg = WSDashboardMessage(type: "events", payload: String(data: json, encoding: .utf8) ?? "[]")
            if let data = try? JSONEncoder().encode(msg) {
                sendWSFrame(String(data: data, encoding: .utf8) ?? "", to: conn)
            }
        }
    }

    private func receiveWSFrames(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 2, maximumLength: 65_536) { [weak self] data, _, isComplete, error in
            Task { [weak self] in
                guard let self else { return }
                if let data {
                    let text = self.decodeWSFrame(data)
                    if text == "ping" {
                        self.sendWSFrame("pong", to: conn)
                    }
                }
                if error == nil, !isComplete {
                    await self.receiveWSFrames(on: conn)
                }
            }
        }
    }

    private func sendWSFrame(_ text: String, to conn: NWConnection) {
        let payload = Data(text.utf8)
        var frame = Data()
        frame.append(0x81) // FIN + text opcode
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

    private func decodeWSFrame(_ data: Data) -> String? {
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
            for i in 0..<payload.count {
                payload[i] ^= maskKey[i % 4]
            }
        }
        return String(bytes: payload, encoding: .utf8)
    }

    // MARK: - Broadcasting

    private func broadcastEntryChanges(_ entries: [NetworkEntry]) {
        guard !wsConnections.isEmpty else { return }
        if entries.isEmpty {
            knownSignatures.removeAll()
            broadcastWS(WSDashboardMessage(type: "clear", payload: ""))
            return
        }
        for entry in entries {
            let key = entry.effectiveID
            let sig = WDEntrySignature(entry)
            if knownSignatures[key] != sig {
                knownSignatures[key] = sig
                if let json = try? JSONEncoder().encode(entry),
                   let str = String(data: json, encoding: .utf8) {
                    broadcastWS(WSDashboardMessage(type: "entry", payload: str))
                }
            }
        }
    }

    private func broadcastLogChanges(_ messages: [LogMessage]) {
        guard !wsConnections.isEmpty else { return }
        for msg in messages where !knownLogIDs.contains(msg.id) {
            knownLogIDs.insert(msg.id)
            if let json = try? JSONEncoder().encode(msg),
               let str = String(data: json, encoding: .utf8) {
                broadcastWS(WSDashboardMessage(type: "log", payload: str))
            }
        }
    }

    private func broadcastEventChanges(_ events: [AnalyticsEvent]) {
        guard !wsConnections.isEmpty else { return }
        for event in events where !knownEventIDs.contains(event.id) {
            knownEventIDs.insert(event.id)
            if let json = try? JSONEncoder().encode(event),
               let str = String(data: json, encoding: .utf8) {
                broadcastWS(WSDashboardMessage(type: "event", payload: str))
            }
        }
    }

    private func broadcastWS(_ message: WSDashboardMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let str = String(data: data, encoding: .utf8) else { return }
        for (_, conn) in wsConnections {
            sendWSFrame(str, to: conn)
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

struct WSDashboardMessage: Codable {
    let type: String
    let payload: String
}
