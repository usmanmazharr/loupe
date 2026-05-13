import XCTest
@testable import Loupe

final class LogManagerTests: XCTestCase {

    var storage: InMemoryStorage!

    override func setUp() async throws {
        storage = InMemoryStorage(maxCount: 10)
        // Note: LogManager.shared is a singleton; tests use InMemoryStorage directly.
    }

    // MARK: - Storage

    func test_add_storesEntry() async throws {
        let entry = makeEntry()
        await storage.add(entry)
        let all = await storage.allEntries()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, entry.id)
    }

    func test_add_enforcesMaxCount() async throws {
        for _ in 0..<15 {
            await storage.add(makeEntry())
        }
        let all = await storage.allEntries()
        XCTAssertLessThanOrEqual(all.count, 10)
    }

    func test_update_modifiesExistingEntry() async throws {
        let entry = makeEntry()
        await storage.add(entry)
        entry.statusCode = 200
        await storage.update(entry)
        let fetched = await storage.entry(id: entry.id)
        XCTAssertEqual(fetched?.statusCode, 200)
    }

    func test_removeAll_clearsStorage() async throws {
        await storage.add(makeEntry())
        await storage.add(makeEntry())
        await storage.removeAll()
        let all = await storage.allEntries()
        XCTAssertTrue(all.isEmpty)
    }

    func test_remove_byId_removesCorrectEntry() async throws {
        let e1 = makeEntry()
        let e2 = makeEntry()
        await storage.add(e1)
        await storage.add(e2)
        await storage.remove(ids: [e1.id])
        let all = await storage.allEntries()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, e2.id)
    }

    // MARK: - Publisher

    func test_publisher_emitsOnAdd() async throws {
        let expectation = expectation(description: "publisher emits")
        let cancellable = storage.entriesPublisher.dropFirst().sink { entries in
            if !entries.isEmpty { expectation.fulfill() }
        }

        await storage.add(makeEntry())
        await fulfillment(of: [expectation], timeout: 1)
        cancellable.cancel()
    }

    // MARK: - Helpers

    private func makeEntry() -> NetworkEntry {
        NetworkEntry(
            url: URL(string: "https://api.example.com/users")!,
            method: "GET"
        )
    }
}
