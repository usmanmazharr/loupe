import Foundation
import Combine

/// Thread-safe, in-memory store for `NetworkEntry` values.
public final class InMemoryStorage: NetworkEntryStorage, @unchecked Sendable {

    private let maxCount: Int
    private var entries: [NetworkEntry] = []
    private let lock = NSLock()

    private let subject = CurrentValueSubject<[NetworkEntry], Never>([])

    public var entriesPublisher: AnyPublisher<[NetworkEntry], Never> {
        subject.eraseToAnyPublisher()
    }

    public init(maxCount: Int = 500) {
        self.maxCount = maxCount
    }

    public func add(_ entry: NetworkEntry) async {
        lock.withLock {
            entries.append(entry)
            if entries.count > maxCount {
                entries.removeFirst(entries.count - maxCount)
            }
        }
        publish()
    }

    public func update(_ entry: NetworkEntry) async {
        lock.withLock {
            if let idx = entries.firstIndex(where: { $0.id == entry.id }) {
                entries[idx] = entry
            }
        }
        publish()
    }

    public func remove(ids: Set<UUID>) async {
        lock.withLock {
            entries.removeAll { ids.contains($0.id) }
        }
        publish()
    }

    public func removeAll() async {
        lock.withLock { entries.removeAll() }
        publish()
    }

    public func entry(id: UUID) async -> NetworkEntry? {
        lock.withLock { entries.first { $0.id == id } }
    }

    public func allEntries() async -> [NetworkEntry] {
        lock.withLock { entries }
    }

    // MARK: Private

    private func publish() {
        let snapshot = lock.withLock { entries }
        subject.send(snapshot)
    }
}

// NSLock convenience
private extension NSLock {
    @discardableResult
    func withLock<T>(_ block: () -> T) -> T {
        lock()
        defer { unlock() }
        return block()
    }
}
