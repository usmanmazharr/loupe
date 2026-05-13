import Foundation
import NaturalLanguage

/// macOS-side on-device semantic search — mirrors the iOS implementation
/// but operates on `MacNetworkEntry`.
final class MacSemanticSearch {

    static let shared = MacSemanticSearch()

    static let matchThreshold: Double = 0.85

    private let queue = DispatchQueue(label: "com.loupe.mac.semantic", qos: .userInitiated)
    private lazy var embedding: NLEmbedding? = {
        NLEmbedding.sentenceEmbedding(for: .english)
            ?? NLEmbedding.wordEmbedding(for: .english)
    }()

    private var entryVectorCache: [UUID: [Double]] = [:]
    private var queryCache: [String: [Double]] = [:]

    var isAvailable: Bool { embedding != nil }

    func rank(_ entries: [MacNetworkEntry], query: String) -> [MacNetworkEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let q = vector(forQuery: trimmed) else { return [] }
        let scored: [(MacNetworkEntry, Double)] = entries.compactMap { e in
            guard let v = vector(for: e) else { return nil }
            let d = cosineDistance(q, v)
            return d < Self.matchThreshold ? (e, d) : nil
        }
        return scored.sorted { $0.1 < $1.1 }.map(\.0)
    }

    func clearCache() {
        queue.sync {
            entryVectorCache.removeAll()
            queryCache.removeAll()
        }
    }

    private func vector(forQuery q: String) -> [Double]? {
        let key = q.lowercased()
        if let cached = queue.sync(execute: { queryCache[key] }) { return cached }
        guard let embedding, let v = embedding.vector(for: key) else { return nil }
        queue.sync { queryCache[key] = v }
        return v
    }

    private func vector(for entry: MacNetworkEntry) -> [Double]? {
        if let cached = queue.sync(execute: { entryVectorCache[entry.id] }) { return cached }
        guard let embedding else { return nil }
        let summary = summarize(entry).lowercased()
        guard let v = embedding.vector(for: summary) else { return nil }
        queue.sync { entryVectorCache[entry.id] = v }
        return v
    }

    private func summarize(_ entry: MacNetworkEntry) -> String {
        var parts: [String] = [entry.method, entry.url.path]
        if let host = entry.url.host { parts.append(host) }
        if let code = entry.statusCode { parts.append("status \(code) \(classWord(code))") }
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

    private func classWord(_ code: Int) -> String {
        switch code {
        case 200..<300: return "success ok"
        case 300..<400: return "redirect"
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

    private func cosineDistance(_ a: [Double], _ b: [Double]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return .greatestFiniteMagnitude }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in 0..<n { dot += a[i]*b[i]; na += a[i]*a[i]; nb += b[i]*b[i] }
        guard na > 0, nb > 0 else { return .greatestFiniteMagnitude }
        return 1.0 - dot / (sqrt(na) * sqrt(nb))
    }
}
