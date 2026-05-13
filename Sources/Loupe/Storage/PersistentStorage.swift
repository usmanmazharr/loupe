import Foundation
import Combine

/// File-based JSON storage that persists entries across app launches.
/// Wraps `InMemoryStorage` for reactive publishing and uses a background queue for I/O.
public final class PersistentStorage: NetworkEntryStorage, @unchecked Sendable {

    private let memoryStore: InMemoryStorage
    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "com.loupe.storage.io", qos: .utility)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public var entriesPublisher: AnyPublisher<[NetworkEntry], Never> {
        memoryStore.entriesPublisher
    }

    public init(maxCount: Int = 500, directoryURL: URL? = nil) {
        self.memoryStore = InMemoryStorage(maxCount: maxCount)
        let dir = directoryURL ?? FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Loupe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("network_log.json")
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        decoder.dateDecodingStrategy = .iso8601
        loadFromDisk()
    }

    public func add(_ entry: NetworkEntry) async {
        await memoryStore.add(entry)
        saveToDisk()
    }

    public func update(_ entry: NetworkEntry) async {
        await memoryStore.update(entry)
        saveToDisk()
    }

    public func remove(ids: Set<UUID>) async {
        await memoryStore.remove(ids: ids)
        saveToDisk()
    }

    public func removeAll() async {
        await memoryStore.removeAll()
        saveToDisk()
    }

    public func entry(id: UUID) async -> NetworkEntry? {
        await memoryStore.entry(id: id)
    }

    public func allEntries() async -> [NetworkEntry] {
        await memoryStore.allEntries()
    }

    // MARK: - Disk I/O

    private func loadFromDisk() {
        ioQueue.async { [weak self] in
            guard let self, let data = try? Data(contentsOf: self.fileURL) else { return }
            if let entries = try? self.decoder.decode([NetworkEntry].self, from: data) {
                Task {
                    for entry in entries {
                        await self.memoryStore.add(entry)
                    }
                }
            }
        }
    }

    private func saveToDisk() {
        ioQueue.async { [weak self] in
            guard let self else { return }
            Task {
                let entries = await self.memoryStore.allEntries()
                if let data = try? self.encoder.encode(entries) {
                    try? data.write(to: self.fileURL, options: .atomic)
                }
            }
        }
    }
}
