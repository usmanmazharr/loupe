import Foundation
import Network
import Combine

actor WebDashboardServer {

    private var listener: NWListener?
    private let port: UInt16
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    init(port: UInt16 = 9800) {
        self.port = port
    }

    func start() {
        guard listener == nil else { return }
        do {
            let params = NWParameters.tcp
            let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            l.stateUpdateHandler = { state in
                if case .ready = state { print("[WebDashboard] listening on port \(self.port)") }
                if case .failed(let e) = state { print("[WebDashboard] error: \(e)") }
            }
            l.newConnectionHandler = { [weak self] conn in
                guard let self else { return }
                conn.start(queue: .global(qos: .utility))
                self.receive(on: conn)
            }
            l.start(queue: .global(qos: .utility))
            self.listener = l
            print("[WebDashboard] started on port \(port)")
        } catch {
            print("[WebDashboard] failed: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
    }

    func getPort() -> UInt16 { port }

    // MARK: - Receive

    private nonisolated func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
            guard let self, let data, let raw = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }
            Task { await self.handle(raw, on: conn) }
        }
    }

    // MARK: - Handle

    private func handle(_ raw: String, on conn: NWConnection) async {
        let lines = raw.components(separatedBy: "\r\n")
        guard let first = lines.first else { respond(conn, status: "400 Bad Request", body: Data()); return }
        let tokens = first.split(separator: " ", maxSplits: 2)
        guard tokens.count >= 2 else { respond(conn, status: "400 Bad Request", body: Data()); return }
        let method = String(tokens[0])
        let path = String(tokens[1])

        switch (method, path) {
        case ("GET", "/"):
            respond(conn, status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(WebDashboardHTML.page.utf8))

        case ("GET", "/api/entries"):
            let entries = await LogManager.shared.allEntries()
            respond(conn, status: "200 OK", body: (try? encoder.encode(entries)) ?? Data("[]".utf8))

        case ("GET", "/api/logs"):
            let logs = await LogMessageStore.shared.allMessages()
            respond(conn, status: "200 OK", body: (try? encoder.encode(logs)) ?? Data("[]".utf8))

        case ("GET", "/api/events"):
            let events = await AnalyticsEventStore.shared.allEvents()
            respond(conn, status: "200 OK", body: (try? encoder.encode(events)) ?? Data("[]".utf8))

        case ("GET", let p) where p.hasPrefix("/api/entries/"):
            let idStr = String(p.dropFirst("/api/entries/".count))
            if let uuid = UUID(uuidString: idStr),
               let entry = (await LogManager.shared.allEntries()).first(where: { $0.effectiveID == uuid }) {
                respond(conn, status: "200 OK", body: (try? encoder.encode(entry)) ?? Data("{}".utf8))
            } else {
                respond(conn, status: "404 Not Found", body: Data("{\"error\":\"not found\"}".utf8))
            }

        case ("DELETE", "/api/entries"):
            await LogManager.shared.clearAll(keepingPinned: false)
            respond(conn, status: "200 OK", body: Data("{\"ok\":true}".utf8))

        default:
            respond(conn, status: "404 Not Found", contentType: "text/plain", body: Data("Not Found".utf8))
        }
    }

    // MARK: - Respond

    private nonisolated func respond(_ conn: NWConnection, status: String, contentType: String = "application/json", body: Data) {
        let header = "HTTP/1.1 \(status)\r\nContent-Type: \(contentType)\r\nContent-Length: \(body.count)\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n"
        var data = Data(header.utf8)
        data.append(body)
        conn.send(content: data, completion: .contentProcessed { _ in conn.cancel() })
    }
}
