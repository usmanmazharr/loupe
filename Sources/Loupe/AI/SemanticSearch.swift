import Foundation
import NaturalLanguage

/// On-device semantic search over `NetworkEntry` using Apple's `NLEmbedding`.
/// No network calls, no model bundling — uses the built-in English sentence
/// embedding (available since iOS 14 / macOS 11). Works alongside the regular
/// substring search and can be toggled on/off in the UI.
final class SemanticSearch {

    static let shared = SemanticSearch()

    /// Maximum cosine distance considered a "match". Lower is stricter.
    static let matchThreshold: Double = 0.85

    private let queue = DispatchQueue(label: "com.loupe.semantic", qos: .userInitiated)
    private lazy var embedding: NLEmbedding? = {
        NLEmbedding.sentenceEmbedding(for: .english)
            ?? NLEmbedding.wordEmbedding(for: .english)
    }()

    private var entryVectorCache: [UUID: [Double]] = [:]
    private var querySummaryCache: [String: [Double]] = [:]

    /// Returns true when the embedding model was loaded successfully.
    var isAvailable: Bool { embedding != nil }

    // MARK: - Public API

    /// Returns the subset of `entries` semantically related to `query`,
    /// sorted by similarity (closest first). Returns an empty array if
    /// the model is unavailable or `query` is empty.
    func rank(_ entries: [NetworkEntry], query: String) -> [NetworkEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let queryVector = vector(forQuery: trimmed) else { return [] }

        let scored: [(NetworkEntry, Double)] = entries.compactMap { entry in
            guard let entryVector = vector(for: entry) else { return nil }
            let distance = cosineDistance(queryVector, entryVector)
            guard distance < Self.matchThreshold else { return nil }
            return (entry, distance)
        }
        return scored.sorted { $0.1 < $1.1 }.map(\.0)
    }

    /// Drops cached vectors. Call after `clearAll` or when entries are evicted.
    func clearCache() {
        queue.sync {
            entryVectorCache.removeAll()
            querySummaryCache.removeAll()
        }
    }

    // MARK: - Vector building

    private func vector(forQuery query: String) -> [Double]? {
        let key = query.lowercased()
        if let cached = queue.sync(execute: { querySummaryCache[key] }) { return cached }
        guard let embedding, let v = embedding.vector(for: key) else { return nil }
        queue.sync { querySummaryCache[key] = v }
        return v
    }

    private func vector(for entry: NetworkEntry) -> [Double]? {
        let id = entry.effectiveID
        if let cached = queue.sync(execute: { entryVectorCache[id] }) { return cached }

        guard let embedding else { return nil }
        let summary = summarize(entry).lowercased()
        guard let v = embedding.vector(for: summary) else { return nil }
        queue.sync { entryVectorCache[id] = v }
        return v
    }

    /// Produces a short sentence-like description of the entry used as the
    /// embedding input. Mixes structural fields (method, path, status) with
    /// any natural-language bits we can extract from the body so a query like
    /// "login failed" can find a 401 whose body says `{"error": "invalid_credentials"}`.
    private func summarize(_ entry: NetworkEntry) -> String {
        var parts: [String] = [entry.method, entry.url.path]
        if let host = entry.url.host { parts.append(host) }
        if let code = entry.statusCode { parts.append("status \(code) \(httpClassWord(code))") }
        if entry.status == .failed { parts.append("failed network error") }
        if entry.isMocked { parts.append("mocked") }
        if let err = entry.error { parts.append("error \(err.localizedDescription)") }

        if let body = entry.responseBody,
           let obj = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            if let msg = obj["message"] as? String, !msg.isEmpty { parts.append(msg) }
            if let err = obj["error"] as? String,   !err.isEmpty { parts.append("error \(err)") }
            let keys = obj.keys.sorted().prefix(8).joined(separator: " ")
            if !keys.isEmpty { parts.append(keys) }
        }
        return parts.joined(separator: " ")
    }

    private func httpClassWord(_ code: Int) -> String {
        switch code {
        case 200..<300: return "success ok"
        case 300..<400: return "redirect"
        case 400:       return "bad request"
        case 401:       return "unauthorized auth login failed"
        case 403:       return "forbidden permission denied"
        case 404:       return "not found missing"
        case 408:       return "timeout slow"
        case 429:       return "rate limited throttled"
        case 400..<500: return "client error"
        case 500..<600: return "server error backend down crash"
        default:        return ""
        }
    }

    // MARK: - Math

    private func cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return .greatestFiniteMagnitude }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<n {
            dot += a[i] * b[i]
            na  += a[i] * a[i]
            nb  += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return .greatestFiniteMagnitude }
        return 1.0 - (dot / (sqrt(na) * sqrt(nb)))
    }
}
