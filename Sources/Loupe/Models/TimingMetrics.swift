import Foundation

/// Granular timing data for a single network transaction.
public struct TimingMetrics: Codable, Sendable {

    /// Absolute start of the request (URLProtocol `startLoading` called).
    public let startDate: Date

    /// Time the TCP connection was established (nil if reused).
    public var connectDate: Date?

    /// Time the first response byte was received.
    public var firstByteDate: Date?

    /// Time the response was fully received.
    public var endDate: Date?

    /// Total round-trip duration in seconds.
    public var totalDuration: TimeInterval? {
        endDate.map { $0.timeIntervalSince(startDate) }
    }

    /// Time from start to first byte (TTFB) in seconds.
    public var timeToFirstByte: TimeInterval? {
        guard let fb = firstByteDate else { return nil }
        return fb.timeIntervalSince(startDate)
    }

    /// Time spent downloading the body after first byte.
    public var downloadDuration: TimeInterval? {
        guard let end = endDate, let fb = firstByteDate else { return nil }
        return end.timeIntervalSince(fb)
    }

    // MARK: - Display

    /// Human-readable total duration (e.g. "245 ms").
    public var formattedDuration: String {
        guard let d = totalDuration else { return "—" }
        if d < 1 { return String(format: "%.0f ms", d * 1_000) }
        return String(format: "%.2f s", d)
    }

    public init(startDate: Date = Date()) {
        self.startDate = startDate
    }
}
