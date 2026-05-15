import Foundation
import Network

final class MockLocalServer {

    private var listener: NWListener?
    private let port: UInt16
    private var endpoints: [MockEndpoint] = []
    private let queue = DispatchQueue(label: "com.loupe.mockserver", qos: .utility)
    private(set) var isRunning = false
    var onLog: ((String) -> Void)?

    init(port: UInt16 = 8080) {
        self.port = port
    }

    func updateEndpoints(_ eps: [MockEndpoint]) {
        queue.async { self.endpoints = eps }
    }

    func start() throws {
        guard !isRunning else { return }
        let params = NWParameters.tcp
        let l = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        l.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.isRunning = true
                self.log("Mock server listening on port \(self.port)")
            case .failed(let err):
                self.isRunning = false
                self.log("Mock server failed: \(err)")
            case .cancelled:
                self.isRunning = false
            default: break
            }
        }
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: self?.queue ?? .global())
            self?.receive(on: conn)
        }
        l.start(queue: queue)
        listener = l
    }

    func stop() {
        listener?.cancel()
        listener = nil
        isRunning = false
        log("Mock server stopped")
    }

    // MARK: - HTTP handling

    private func receive(on conn: NWConnection) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, _, _ in
            guard let self, let data, let raw = String(data: data, encoding: .utf8) else {
                conn.cancel()
                return
            }
            self.handle(raw, on: conn)
        }
    }

    private func handle(_ raw: String, on conn: NWConnection) {
        let lines = raw.components(separatedBy: "\r\n")
        guard let first = lines.first else { respond(conn, status: 400, statusText: "Bad Request", body: Data()); return }
        let tokens = first.split(separator: " ", maxSplits: 2)
        guard tokens.count >= 2 else { respond(conn, status: 400, statusText: "Bad Request", body: Data()); return }
        let method = String(tokens[0]).uppercased()
        let rawPath = String(tokens[1])
        let path = rawPath.components(separatedBy: "?").first ?? rawPath

        if method == "OPTIONS" {
            respondCORS(conn)
            return
        }

        let match = endpoints.first { ep in
            ep.isEnabled && ep.method.uppercased() == method && ep.displayPath == path
        }

        guard let mock = match else {
            let body = "{\"error\":\"No mock found for \(method) \(path)\"}".data(using: .utf8) ?? Data()
            log("\(method) \(path) → 404 (no mock)")
            respond(conn, status: 404, statusText: "Not Found", headers: ["Content-Type": "application/json"], body: body)
            return
        }

        let responseData = mock.responseBody.data(using: .utf8) ?? Data()
        let delay = mock.delay

        let doRespond = { [weak self] in
            self?.log("\(method) \(path) → \(mock.statusCode)")
            self?.respond(conn, status: mock.statusCode, statusText: Self.httpStatusText(mock.statusCode), headers: mock.responseHeaders, body: responseData)
        }

        if delay > 0 {
            queue.asyncAfter(deadline: .now() + delay, execute: doRespond)
        } else {
            doRespond()
        }
    }

    private func respond(_ conn: NWConnection, status: Int, statusText: String, headers: [String: String] = [:], body: Data) {
        var headerStr = "HTTP/1.1 \(status) \(statusText)\r\n"
        headerStr += "Content-Length: \(body.count)\r\n"
        headerStr += "Access-Control-Allow-Origin: *\r\n"
        headerStr += "Access-Control-Allow-Methods: GET, POST, PUT, PATCH, DELETE, OPTIONS\r\n"
        headerStr += "Access-Control-Allow-Headers: *\r\n"
        headerStr += "Connection: close\r\n"
        for (k, v) in headers {
            headerStr += "\(k): \(v)\r\n"
        }
        headerStr += "\r\n"
        var data = Data(headerStr.utf8)
        data.append(body)
        conn.send(content: data, completion: .contentProcessed { _ in conn.cancel() })
    }

    private func respondCORS(_ conn: NWConnection) {
        respond(conn, status: 204, statusText: "No Content", headers: ["Content-Type": "text/plain"], body: Data())
    }

    private func log(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(ts)] \(msg)"
        DispatchQueue.main.async { self.onLog?(line) }
    }

    static func httpStatusText(_ code: Int) -> String {
        switch code {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        case 409: return "Conflict"
        case 422: return "Unprocessable Entity"
        case 429: return "Too Many Requests"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return "OK"
        }
    }
}
