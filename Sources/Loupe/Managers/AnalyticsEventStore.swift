import Foundation
import Combine

/// In-memory ring buffer for analytics events captured via
/// `Loupe.shared.trackEvent(...)`. Same shape as `LogMessageStore`.
public actor AnalyticsEventStore {

    public static let shared = AnalyticsEventStore()

    private var buffer: [AnalyticsEvent] = []
    private var capacity: Int = 2_000
    private var currentScreen: String?

    private let subject = CurrentValueSubject<[AnalyticsEvent], Never>([])
    nonisolated let eventsPublisher: AnyPublisher<[AnalyticsEvent], Never>

    private init() {
        eventsPublisher = subject.eraseToAnyPublisher()
    }

    // MARK: - Public

    public func setCapacity(_ n: Int) { capacity = max(50, n) }

    /// Sets the name of the currently visible screen. All events fired after
    /// this call (without an explicit `screen` parameter) are attributed to it.
    public func setCurrentScreen(_ name: String?) {
        currentScreen = name?.isEmpty == true ? nil : name
    }

    public func track(_ name: String,
                      provider: String = "Custom",
                      properties: [String: String] = [:],
                      screen: String? = nil) {
        let resolvedScreen = screen ?? currentScreen
        let event = AnalyticsEvent(provider: provider,
                                   name: name,
                                   properties: properties,
                                   screen: resolvedScreen)
        buffer.append(event)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
        subject.send(buffer)
    }

    public func clearAll() {
        buffer.removeAll()
        subject.send([])
    }

    public func allEvents() -> [AnalyticsEvent] { buffer }
}
