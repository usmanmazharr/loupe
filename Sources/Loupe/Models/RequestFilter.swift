import Foundation

// MARK: - Sort Order

public enum SortOrder: String, CaseIterable, Identifiable {
    case newest         = "Newest First"
    case oldest         = "Oldest First"
    case slowest        = "Slowest First"
    case fastest        = "Fastest First"
    case largestResponse = "Largest Response"
    public var id: String { rawValue }
}

// MARK: - Status Filter

public enum StatusFilter: String, CaseIterable, Identifiable {
    case all         = "All"
    case success     = "2xx"
    case redirect    = "3xx"
    case clientError = "4xx"
    case serverError = "5xx"
    case failed      = "Failed"
    case pending     = "Pending"
    public var id: String { rawValue }

    func matches(_ entry: NetworkEntry) -> Bool {
        switch self {
        case .all:         return true
        case .success:     return entry.statusCode.map { (200..<300).contains($0) } ?? false
        case .redirect:    return entry.statusCode.map { (300..<400).contains($0) } ?? false
        case .clientError: return entry.statusCode.map { (400..<500).contains($0) } ?? false
        case .serverError: return entry.statusCode.map { (500..<600).contains($0) } ?? false
        case .failed:      return entry.status == .failed || entry.error != nil
        case .pending:     return !entry.status.isTerminal
        }
    }

    /// Status class integer (2 for 2xx, 3 for 3xx, etc.) — used by summary strip.
    var statusClass: Int? {
        switch self {
        case .success:     return 2
        case .redirect:    return 3
        case .clientError: return 4
        case .serverError: return 5
        default:           return nil
        }
    }
}

// MARK: - Method Filter

public enum MethodFilter: String, CaseIterable, Identifiable {
    case all     = "All"
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case patch   = "PATCH"
    case delete  = "DELETE"
    case head    = "HEAD"
    case options = "OPTIONS"
    public var id: String { rawValue }

    func matches(_ entry: NetworkEntry) -> Bool {
        self == .all || entry.method == rawValue
    }
}

// MARK: - RequestFilter

public struct RequestFilter {
    public var searchText:      String       = ""
    public var statusFilter:    StatusFilter = .all
    public var methodFilter:    MethodFilter = .all
    public var hostFilter:      String       = ""
    public var excludedDomains: Set<String>  = []
    public var sortOrder:       SortOrder    = .newest
    public var showOnlyFailed:  Bool         = false
    public var showOnlyMocked:  Bool         = false
    /// Max response time in seconds (5.0 = no limit).
    public var maxDuration:     Double       = 5.0

    public init() {}

    public var isActive: Bool {
        !searchText.isEmpty || statusFilter != .all || methodFilter != .all ||
        !hostFilter.isEmpty || !excludedDomains.isEmpty || showOnlyFailed ||
        showOnlyMocked || maxDuration < 5.0
    }

    func apply(to entries: [NetworkEntry]) -> [NetworkEntry] {
        var result = entries

        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter { entry in
                if entry.url.absoluteString.lowercased().contains(q) { return true }
                if entry.method.lowercased().contains(q) { return true }
                if entry.statusCode.map({ String($0).contains(q) }) ?? false { return true }
                if entry.host.lowercased().contains(q) { return true }
                for (k, v) in entry.requestHeaders {
                    if k.lowercased().contains(q) || v.lowercased().contains(q) { return true }
                }
                for (k, v) in entry.queryParameters {
                    if k.lowercased().contains(q) || v.lowercased().contains(q) { return true }
                }
                if let body = entry.requestBody,
                   let text = String(data: body, encoding: .utf8),
                   text.lowercased().contains(q) { return true }
                if let body = entry.responseBody,
                   let text = String(data: body, encoding: .utf8),
                   text.lowercased().contains(q) { return true }
                return false
            }
        }
        if statusFilter != .all  { result = result.filter { statusFilter.matches($0) } }
        if methodFilter != .all  { result = result.filter { methodFilter.matches($0) } }
        if !hostFilter.isEmpty   { result = result.filter { $0.host.contains(hostFilter) } }
        if !excludedDomains.isEmpty { result = result.filter { !excludedDomains.contains($0.host) } }
        if showOnlyFailed  { result = result.filter { $0.error != nil || $0.status == .failed } }
        if showOnlyMocked  { result = result.filter { $0.isMocked } }
        if maxDuration < 5.0 {
            result = result.filter { ($0.timing.totalDuration ?? 0) <= maxDuration }
        }

        switch sortOrder {
        case .newest:          result.sort { $0.timing.startDate > $1.timing.startDate }
        case .oldest:          result.sort { $0.timing.startDate < $1.timing.startDate }
        case .slowest:         result.sort { ($0.timing.totalDuration ?? 0) > ($1.timing.totalDuration ?? 0) }
        case .fastest:         result.sort { ($0.timing.totalDuration ?? 0) < ($1.timing.totalDuration ?? 0) }
        case .largestResponse: result.sort { $0.responseSize > $1.responseSize }
        }

        return result
    }
}
