import XCTest
@testable import Loupe

final class SecurityManagerTests: XCTestCase {

    var sut: SecurityManager!

    override func setUp() {
        var config = LoupeConfiguration()
        config.sensitiveHeaders = ["Authorization", "Cookie"]
        config.sensitiveBodyKeys = ["password", "token"]
        config.maskingString = "••••"
        sut = SecurityManager(configuration: config)
    }

    // MARK: - Header masking

    func test_sanitizeHeaders_masksSensitiveKey() {
        let headers = ["Authorization": "Bearer abc123", "Content-Type": "application/json"]
        let result = sut.sanitize(headers: headers)
        XCTAssertEqual(result["Authorization"], "••••")
        XCTAssertEqual(result["Content-Type"], "application/json")
    }

    func test_sanitizeHeaders_isCaseInsensitive() {
        let headers = ["authorization": "Bearer xyz"]
        let result = sut.sanitize(headers: headers)
        XCTAssertEqual(result["authorization"], "••••")
    }

    func test_sanitizeHeaders_passesNonSensitiveHeadersThrough() {
        let headers = ["X-Custom-Header": "some-value"]
        let result = sut.sanitize(headers: headers)
        XCTAssertEqual(result["X-Custom-Header"], "some-value")
    }

    // MARK: - Body masking

    func test_sanitizeBody_masksPasswordKey() throws {
        let json = #"{"username":"alice","password":"secret123"}"#
        let data = json.data(using: .utf8)!
        let sanitized = sut.sanitize(body: data)!
        let obj = try JSONSerialization.jsonObject(with: sanitized) as! [String: String]
        XCTAssertEqual(obj["password"], "••••")
        XCTAssertEqual(obj["username"], "alice")
    }

    func test_sanitizeBody_masksNestedSensitiveKey() throws {
        let json = #"{"user":{"token":"abc","name":"Bob"}}"#
        let data = json.data(using: .utf8)!
        let sanitized = sut.sanitize(body: data)!
        let obj = try JSONSerialization.jsonObject(with: sanitized) as! [String: [String: String]]
        XCTAssertEqual(obj["user"]?["token"], "••••")
        XCTAssertEqual(obj["user"]?["name"], "Bob")
    }

    func test_sanitizeBody_returnsNilInputUnchanged() {
        XCTAssertNil(sut.sanitize(body: nil))
    }

    func test_sanitizeBody_returnsNonJSONUnchanged() {
        let data = "plain text".data(using: .utf8)!
        let result = sut.sanitize(body: data)
        XCTAssertEqual(result, data)
    }

    // MARK: - URL masking

    func test_sanitizeURL_masksQueryParameter() {
        let url = URL(string: "https://api.example.com/auth?password=secret&page=1")!
        let sanitized = sut.sanitize(url: url)
        let components = URLComponents(url: sanitized, resolvingAgainstBaseURL: false)!
        let passwordItem = components.queryItems?.first(where: { $0.name == "password" })
        XCTAssertEqual(passwordItem?.value, "••••")
        let pageItem = components.queryItems?.first(where: { $0.name == "page" })
        XCTAssertEqual(pageItem?.value, "1")
    }
}
