import Foundation

struct MockEndpoint: Identifiable, Codable, Equatable {
    var id = UUID()
    var path: String = "/example"
    var method: String = "GET"
    var statusCode: Int = 200
    var responseBody: String = "{\n  \"message\": \"Hello from Loupe mock\"\n}"
    var responseHeaders: [String: String] = ["Content-Type": "application/json"]
    var delay: TimeInterval = 0
    var isEnabled: Bool = true

    var displayPath: String {
        path.hasPrefix("/") ? path : "/" + path
    }
}
