import Foundation
import Combine

/// Rule-based HTTP response stubbing engine.
/// Checked by `NetworkInterceptor` before every outgoing request.
public final class MockEngine: ObservableObject, @unchecked Sendable {

    public static let shared = MockEngine()

    @Published public var isEnabled: Bool = true
    @Published public var rules: [MockRule] = []

    private init() {}

    // MARK: - Rule management

    public func add(_ rule: MockRule) {
        DispatchQueue.main.async { self.rules.append(rule) }
    }

    public func update(_ rule: MockRule) {
        DispatchQueue.main.async {
            if let idx = self.rules.firstIndex(where: { $0.id == rule.id }) {
                self.rules[idx] = rule
            }
        }
    }

    public func remove(id: UUID) {
        DispatchQueue.main.async { self.rules.removeAll { $0.id == id } }
    }

    public func removeAll() {
        DispatchQueue.main.async { self.rules.removeAll() }
    }

    public func toggleRule(id: UUID) {
        DispatchQueue.main.async {
            if let idx = self.rules.firstIndex(where: { $0.id == id }) {
                self.rules[idx].isEnabled.toggle()
            }
        }
    }

    // MARK: - Lookup (called from interceptor — any thread)

    /// Returns the first enabled rule that matches `request`, or `nil`.
    func matchingRule(for request: URLRequest) -> MockRule? {
        guard isEnabled else { return nil }
        return rules.first { $0.matches(request) }
    }

    // MARK: - Load from JSON config file

    /// Loads rules from a JSON file bundled with the debug build.
    /// File must be an array of `MockRule` encoded as JSON.
    public func loadRules(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([MockRule].self, from: data)
        else { return }
        DispatchQueue.main.async { self.rules = decoded }
    }
}
