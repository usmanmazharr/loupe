import Foundation

/// Granular per-phase timing extracted from `URLSessionTaskMetrics`.
public struct NetworkTimingDetail: Codable, Sendable {

    public var dnsStart:     Date?
    public var dnsEnd:       Date?
    public var connectStart: Date?
    public var connectEnd:   Date?
    public var tlsStart:     Date?
    public var tlsEnd:       Date?
    public var requestStart: Date?
    public var requestEnd:   Date?
    public var responseStart: Date?
    public var responseEnd:   Date?

    public init() {}

    // MARK: - Phase durations (nil when phase didn't occur, e.g. reused connection)

    public var dnsDuration:      TimeInterval? { diff(dnsStart,      dnsEnd) }
    public var connectDuration:  TimeInterval? { diff(connectStart,  connectEnd) }
    public var tlsDuration:      TimeInterval? { diff(tlsStart,      tlsEnd) }
    public var requestDuration:  TimeInterval? { diff(requestStart,  requestEnd) }
    public var responseDuration: TimeInterval? { diff(responseStart, responseEnd) }

    /// Total duration from earliest start to latest end across all phases.
    public var totalDuration: TimeInterval? {
        let starts = [dnsStart, connectStart, tlsStart, requestStart, responseStart].compactMap { $0 }
        let ends   = [dnsEnd,   connectEnd,   tlsEnd,   requestEnd,   responseEnd  ].compactMap { $0 }
        guard let first = starts.min(), let last = ends.max() else { return nil }
        return last.timeIntervalSince(first)
    }

    /// Earliest absolute start (used as the zero point for waterfall rendering).
    public var absoluteStart: Date? {
        [dnsStart, connectStart, tlsStart, requestStart, responseStart].compactMap { $0 }.min()
    }

    // MARK: - Private

    private func diff(_ start: Date?, _ end: Date?) -> TimeInterval? {
        guard let s = start, let e = end, e > s else { return nil }
        return e.timeIntervalSince(s)
    }
}

// MARK: - Builder from URLSessionTaskMetrics

extension NetworkTimingDetail {
    /// Populates timing from the first transaction in `URLSessionTaskMetrics`.
    init(metrics: URLSessionTaskMetrics) {
        let tx = metrics.transactionMetrics.first
        dnsStart      = tx?.domainLookupStartDate
        dnsEnd        = tx?.domainLookupEndDate
        connectStart  = tx?.connectStartDate
        connectEnd    = tx?.connectEndDate
        tlsStart      = tx?.secureConnectionStartDate
        tlsEnd        = tx?.secureConnectionEndDate
        requestStart  = tx?.requestStartDate
        requestEnd    = tx?.requestEndDate
        responseStart = tx?.responseStartDate
        responseEnd   = tx?.responseEndDate
    }
}
