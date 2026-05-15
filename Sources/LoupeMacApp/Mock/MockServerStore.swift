import Foundation
import SwiftUI

@MainActor
final class MockServerStore: ObservableObject {

    @Published var endpoints: [MockEndpoint] = []
    @Published var isRunning = false
    @Published var port: UInt16 = 8080
    @Published var logs: [String] = []

    private var server: MockLocalServer?
    private let saveURL: URL

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Loupe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("mock_endpoints.json")
        load()
    }

    // MARK: - CRUD

    func add(_ endpoint: MockEndpoint) {
        endpoints.append(endpoint)
        save()
        syncEndpoints()
    }

    func update(_ endpoint: MockEndpoint) {
        if let idx = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
            endpoints[idx] = endpoint
            save()
            syncEndpoints()
        }
    }

    func remove(at offsets: IndexSet) {
        endpoints.remove(atOffsets: offsets)
        save()
        syncEndpoints()
    }

    func remove(id: UUID) {
        endpoints.removeAll { $0.id == id }
        save()
        syncEndpoints()
    }

    func duplicate(_ endpoint: MockEndpoint) {
        var copy = endpoint
        copy.id = UUID()
        copy.path = endpoint.path + "-copy"
        endpoints.append(copy)
        save()
        syncEndpoints()
    }

    func toggleEnabled(_ endpoint: MockEndpoint) {
        if let idx = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
            endpoints[idx].isEnabled.toggle()
            save()
            syncEndpoints()
        }
    }

    // MARK: - Server

    func startServer() {
        guard !isRunning else { return }
        let s = MockLocalServer(port: port)
        s.onLog = { [weak self] line in
            self?.logs.insert(line, at: 0)
            if (self?.logs.count ?? 0) > 200 { self?.logs = Array(self!.logs.prefix(200)) }
        }
        s.updateEndpoints(endpoints)
        do {
            try s.start()
            server = s
            isRunning = true
        } catch {
            logs.insert("[Error] Failed to start: \(error.localizedDescription)", at: 0)
        }
    }

    func stopServer() {
        server?.stop()
        server = nil
        isRunning = false
    }

    func clearLogs() { logs.removeAll() }

    private func syncEndpoints() {
        server?.updateEndpoints(endpoints)
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(endpoints) {
            try? data.write(to: saveURL, options: .atomic)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([MockEndpoint].self, from: data) else { return }
        endpoints = decoded
    }
}
