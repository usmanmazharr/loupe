import Foundation
import Combine

/// Abstract contract for the Loupe storage back-end.
public protocol NetworkEntryStorage: Sendable {
    /// All stored entries in insertion order.
    var entriesPublisher: AnyPublisher<[NetworkEntry], Never> { get }

    func add(_ entry: NetworkEntry) async
    func update(_ entry: NetworkEntry) async
    func remove(ids: Set<UUID>) async
    func removeAll() async
    func entry(id: UUID) async -> NetworkEntry?
    func allEntries() async -> [NetworkEntry]
}
