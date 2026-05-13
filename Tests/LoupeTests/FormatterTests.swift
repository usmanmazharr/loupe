import XCTest
@testable import Loupe

final class FormatterTests: XCTestCase {

    // MARK: - JSON formatter

    func test_jsonFormatter_parsesObject() {
        let json = #"{"name":"Alice","age":30}"#.data(using: .utf8)!
        let node = JSONFormatter.parse(json)
        guard case .object(_, _, let children) = node else {
            XCTFail("Expected .object"); return
        }
        XCTAssertEqual(children.count, 2)
    }

    func test_jsonFormatter_parsesArray() {
        let json = #"[1,2,3]"#.data(using: .utf8)!
        let node = JSONFormatter.parse(json)
        guard case .array(_, _, let children) = node else {
            XCTFail("Expected .array"); return
        }
        XCTAssertEqual(children.count, 3)
    }

    func test_jsonFormatter_returnsNilForInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        XCTAssertNil(JSONFormatter.parse(data))
    }

    func test_jsonFormatter_detectsBoolVsNumber() {
        let json = #"{"flag":true,"count":42}"#.data(using: .utf8)!
        let node = JSONFormatter.parse(json)
        guard case .object(_, _, let children) = node else { return }
        let flag = children.first { $0.key == "flag" }
        let count = children.first { $0.key == "count" }
        guard case .bool(_, _, let boolVal) = flag else { XCTFail("Expected bool"); return }
        guard case .number(_, _, let numVal) = count else { XCTFail("Expected number"); return }
        XCTAssertTrue(boolVal)
        XCTAssertEqual(numVal, 42)
    }

    // MARK: - cURL Generator

    func test_curlGenerator_basicGET() {
        let entry = NetworkEntry(
            url: URL(string: "https://api.example.com/users?page=1")!,
            method: "GET"
        )
        entry.requestHeaders = ["Accept": "application/json"]
        let curl = CURLGenerator.generate(from: entry)
        XCTAssertTrue(curl.contains("curl"))
        XCTAssertTrue(curl.contains("Accept: application/json"))
        XCTAssertTrue(curl.contains("https://api.example.com/users"))
        XCTAssertFalse(curl.contains("-X GET"))  // GET is default, should be omitted
    }

    func test_curlGenerator_postWithBody() {
        let entry = NetworkEntry(
            url: URL(string: "https://api.example.com/login")!,
            method: "POST",
            requestHeaders: ["Content-Type": "application/json"],
            requestBody: #"{"username":"alice"}"#.data(using: .utf8)
        )
        let curl = CURLGenerator.generate(from: entry)
        XCTAssertTrue(curl.contains("-X POST"))
        XCTAssertTrue(curl.contains("--data-raw"))
        XCTAssertTrue(curl.contains("username"))
    }

    // MARK: - Body Formatter

    func test_bodyFormatter_formatsJSON() {
        let json = #"{"key":"value"}"#.data(using: .utf8)!
        let result = BodyFormatter.format(data: json, contentType: .json)
        guard case .json(let str, let tree) = result else { XCTFail(); return }
        XCTAssertTrue(str.contains("key"))
        XCTAssertNotNil(tree)
    }

    func test_bodyFormatter_detectsBinary() {
        let binaryData = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10])
        let result = BodyFormatter.format(data: binaryData, contentType: .unknown(""))
        guard case .binary = result else { XCTFail("Expected binary detection"); return }
    }

    func test_bodyFormatter_emptyData() {
        let result = BodyFormatter.format(data: nil, contentType: .json)
        guard case .empty = result else { XCTFail("Expected empty"); return }
    }

    // MARK: - XML Formatter

    func test_xmlFormatter_prettyPrintsValidXML() {
        let xml = "<root><item>hello</item></root>"
        let result = XMLFormatter.prettyPrint(xml)
        XCTAssertNotNil(result)
        XCTAssertTrue(result!.contains("<item>"))
    }

    func test_xmlFormatter_returnsNilForInvalidXML() {
        let result = XMLFormatter.prettyPrint("not xml at all <<<")
        XCTAssertNil(result)
    }

    // MARK: - Request Filter

    func test_filter_searchByURL() {
        let entries = [
            makeEntry(url: "https://api.example.com/users"),
            makeEntry(url: "https://api.example.com/posts")
        ]
        var filter = RequestFilter()
        filter.searchText = "users"
        let result = filter.apply(to: entries)
        XCTAssertEqual(result.count, 1)
        XCTAssertTrue(result.first?.url.absoluteString.contains("users") ?? false)
    }

    func test_filter_byMethod() {
        let entries = [
            makeEntry(method: "GET"),
            makeEntry(method: "POST"),
            makeEntry(method: "DELETE")
        ]
        var filter = RequestFilter()
        filter.methodFilter = .post
        let result = filter.apply(to: entries)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.method, "POST")
    }

    func test_filter_sortNewest() {
        let e1 = makeEntry()
        Thread.sleep(forTimeInterval: 0.01)
        let e2 = makeEntry()
        var filter = RequestFilter()
        filter.sortOrder = .newest
        let result = filter.apply(to: [e1, e2])
        XCTAssertEqual(result.first?.id, e2.id)
    }

    // MARK: - Helpers

    private func makeEntry(url: String = "https://example.com", method: String = "GET") -> NetworkEntry {
        NetworkEntry(url: URL(string: url)!, method: method)
    }
}
