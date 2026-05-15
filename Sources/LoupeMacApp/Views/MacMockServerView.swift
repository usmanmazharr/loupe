import SwiftUI

struct MacMockServerView: View {

    @EnvironmentObject private var store: MockServerStore
    @State private var showEditor = false
    @State private var editingEndpoint: MockEndpoint?
    @State private var showLogs = false

    var body: some View {
        VStack(spacing: 0) {
            serverHeader
            Divider()
            if showLogs {
                logsPanel
            } else {
                endpointList
            }
        }
    }

    // MARK: - Server header

    private var serverHeader: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(store.isRunning ? Color.lpSuccess : Color.lpFog)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.isRunning ? "Server Running" : "Server Stopped")
                        .font(.system(size: 13, weight: .semibold))
                    if store.isRunning {
                        Text("http://localhost:\(store.port)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.lpFog)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                Button {
                    if store.isRunning { store.stopServer() } else { store.startServer() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: store.isRunning ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(store.isRunning ? "Stop" : "Start")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(store.isRunning ? Color.lpDanger : Color.lpSuccess, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Port")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.lpFog)
                    TextField("8080", value: $store.port, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 70)
                        .disabled(store.isRunning)
                }

                Spacer()

                Button {
                    showLogs.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 10))
                        Text(showLogs ? "Endpoints" : "Logs")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Color.lpAccent)
                }
                .buttonStyle(.plain)

                Button {
                    editingEndpoint = nil
                    showEditor = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 11))
                        Text("Add Mock")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.lpAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(.bar)
        .sheet(isPresented: $showEditor) {
            MockEndpointEditor(endpoint: editingEndpoint) { saved in
                if let existing = editingEndpoint {
                    var updated = saved
                    updated.id = existing.id
                    store.update(updated)
                } else {
                    store.add(saved)
                }
                showEditor = false
            }
        }
    }

    // MARK: - Endpoint list

    private var endpointList: some View {
        Group {
            if store.endpoints.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No mock endpoints")
                        .foregroundStyle(.secondary)
                    Text("Add an endpoint and start the server.\nThen call http://localhost:\(store.port)/your-path from Xcode.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.endpoints) { ep in
                        endpointRow(ep)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func endpointRow(_ ep: MockEndpoint) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(ep.isEnabled ? Color.lpSuccess : Color.lpFog.opacity(0.4))
                .frame(width: 8, height: 8)

            Text(ep.method)
                .font(.system(size: 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Color.lpMethodColor(ep.method), in: RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 2) {
                Text(ep.displayPath)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(ep.isEnabled ? Color.lpInk : Color.lpFog)
                HStack(spacing: 8) {
                    Text("\(ep.statusCode)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.lpStatusColor(ep.statusCode))
                    if ep.delay > 0 {
                        Text("\(Int(ep.delay * 1000))ms delay")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.lpFog)
                    }
                    Text("\(ep.responseBody.count) chars")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.lpFog)
                }
            }

            Spacer()

            Button {
                let url = "http://localhost:\(store.port)\(ep.displayPath)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(Color.lpFog)
            }
            .buttonStyle(.plain)
            .help("Copy http://localhost:\(store.port)\(ep.displayPath)")

            Button {
                store.toggleEnabled(ep)
            } label: {
                Image(systemName: ep.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(ep.isEnabled ? Color.lpSuccess : Color.lpFog)
            }
            .buttonStyle(.plain)
            .help(ep.isEnabled ? "Disable" : "Enable")

            Menu {
                Button("Edit") {
                    editingEndpoint = ep
                    showEditor = true
                }
                Button("Duplicate") { store.duplicate(ep) }
                Divider()
                Button("Delete", role: .destructive) { store.remove(id: ep.id) }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(Color.lpFog)
            }
            .buttonStyle(.plain)
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.vertical, 4)
        .opacity(ep.isEnabled ? 1 : 0.5)
    }

    // MARK: - Logs panel

    private var logsPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Request Log")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.lpFog)
                Spacer()
                Button("Clear") { store.clearLogs() }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.lpDanger)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
            Divider()

            if store.logs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No requests yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(store.logs, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(line.contains("404") || line.contains("Error") ? Color.lpDanger : Color.lpInk)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
            }
        }
    }
}

// MARK: - Endpoint Editor

struct MockEndpointEditor: View {

    let endpoint: MockEndpoint?
    let onSave: (MockEndpoint) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var path: String = "/example"
    @State private var method: String = "GET"
    @State private var statusCode: Int = 200
    @State private var responseBody: String = "{\n  \"message\": \"Hello from Loupe mock\"\n}"
    @State private var headers: [(key: String, value: String, id: UUID)] = [
        (key: "Content-Type", value: "application/json", id: UUID())
    ]
    @State private var delayText: String = "0"

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
    private let statusCodes = [200, 201, 204, 301, 302, 400, 401, 403, 404, 405, 409, 422, 429, 500, 502, 503]

    init(endpoint: MockEndpoint?, onSave: @escaping (MockEndpoint) -> Void) {
        self.endpoint = endpoint
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(endpoint == nil ? "New Mock Endpoint" : "Edit Mock Endpoint")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(path.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Method + Path
                    HStack(spacing: 8) {
                        Picker("", selection: $method) {
                            ForEach(methods, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 110)

                        TextField("/users/me", text: $path)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                    }

                    // Status Code
                    HStack(spacing: 8) {
                        Text("Status Code")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $statusCode) {
                            ForEach(statusCodes, id: \.self) { code in
                                Text("\(code) \(MockLocalServer.httpStatusText(code))")
                                    .tag(code)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    // Delay
                    HStack(spacing: 8) {
                        Text("Delay")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        TextField("0", text: $delayText)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 60)
                        Text("seconds")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    // Response Headers
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("RESPONSE HEADERS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                headers.append((key: "", value: "", id: UUID()))
                            } label: {
                                Label("Add", systemImage: "plus.circle.fill")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(Array(headers.enumerated()), id: \.element.id) { idx, _ in
                            HStack(spacing: 6) {
                                TextField("Key", text: Binding(
                                    get: { headers[idx].key },
                                    set: { headers[idx].key = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))

                                TextField("Value", text: Binding(
                                    get: { headers[idx].value },
                                    set: { headers[idx].value = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11, design: .monospaced))

                                Button {
                                    headers.remove(at: idx)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Divider()

                    // Response Body
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("RESPONSE BODY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Format JSON") { formatJSON() }
                                .font(.system(size: 10))
                                .buttonStyle(.plain)
                                .foregroundStyle(.blue)
                        }
                        TextEditor(text: $responseBody)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(minHeight: 200)
                            .padding(6)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 600, height: 560)
        .onAppear { populateFromEndpoint() }
    }

    private func populateFromEndpoint() {
        guard let ep = endpoint else { return }
        path = ep.path
        method = ep.method
        statusCode = ep.statusCode
        responseBody = ep.responseBody
        delayText = ep.delay > 0 ? String(ep.delay) : "0"
        headers = ep.responseHeaders.map { (key: $0.key, value: $0.value, id: UUID()) }
        if headers.isEmpty {
            headers = [(key: "Content-Type", value: "application/json", id: UUID())]
        }
    }

    private func save() {
        var ep = MockEndpoint()
        ep.path = path.trimmingCharacters(in: .whitespaces)
        if !ep.path.hasPrefix("/") { ep.path = "/" + ep.path }
        ep.method = method
        ep.statusCode = statusCode
        ep.responseBody = responseBody
        ep.delay = max(0, Double(delayText) ?? 0)
        ep.responseHeaders = headers.filter { !$0.key.isEmpty }.reduce(into: [:]) { $0[$1.key] = $1.value }
        onSave(ep)
    }

    private func formatJSON() {
        guard let data = responseBody.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let str = String(data: pretty, encoding: .utf8)
        else { return }
        responseBody = str
    }
}
