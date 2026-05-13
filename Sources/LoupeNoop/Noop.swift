import Foundation

/// Release-build no-op stub. Exposes the same public API surface as the debug
/// Loupe target so host apps compile cleanly without `#if DEBUG` guards.
public enum Loupe {
    public static func start() {}
    public static func stop() {}
    public static func clearLogs() {}
    public static func showLogger() {}
    public static func enableShakeGesture() {}
    public static func disableShakeGesture() {}
    public static func setMaxLogCount(_ count: Int) {}
    public static func addCustomHeaderMasking(_ headerName: String) {}
    public static func addSensitiveKey(_ key: String) {}
    public static func configure(session: URLSessionConfiguration) {}
}

/// No-op mock engine stub.
public final class MockEngine {
    public static let shared = MockEngine()
    private init() {}
    public func add(_ rule: MockRule) {}
    public func removeAll() {}
}

/// No-op mock rule stub.
public struct MockRule {
    public init(
        name: String,
        urlPattern: String,
        method: String? = nil,
        statusCode: Int = 200,
        responseBody: Data? = nil,
        responseHeaders: [String: String] = [:],
        delay: TimeInterval = 0,
        errorType: URLError.Code? = nil
    ) {}
}
