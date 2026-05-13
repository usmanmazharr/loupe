import Foundation
import Combine
import OSLog

/// Actor-isolated central manager. All mutations are thread-safe.
/// Persists to SQLite via `LogStore`; publishes snapshots via Combine.
public actor LogManager {

    public static let shared = LogManager()

    private var configuration = LoupeConfiguration()
    private var securityManager = SecurityManager(configuration: LoupeConfiguration())

    private let subject = CurrentValueSubject<[NetworkEntry], Never>([])
    private let osLog   = Logger(subsystem: "com.loupe", category: "network")

    nonisolated let entriesPublisher: AnyPublisher<[NetworkEntry], Never>

    private init() {
        entriesPublisher = subject.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    func configure(with config: LoupeConfiguration) {
        configuration = config
        securityManager = SecurityManager(configuration: config)
        LogStore.shared.setMaxEntries(config.maxLogCount)
        refreshPublisher()
    }

    // MARK: - Entry lifecycle

    func begin(entry: NetworkEntry) async {
        guard configuration.isEnabled, shouldCapture(entry: entry) else { return }
        entry.requestHeaders = securityManager.sanitize(headers: entry.requestHeaders)
        entry.requestBody    = securityManager.sanitize(body: entry.requestBody)
        entry.status = .inProgress
        LogStore.shared.insert(entry)
        refreshPublisher()
        if configuration.osLogEnabled {
            osLog.debug("→ \(entry.method) \(entry.url.absoluteString)")
        }
    }

    func complete(
        id: UUID,
        responseHeaders: [String: String],
        responseBody: Data?,
        statusCode: Int,
        responseSize: Int64,
        contentType: ContentType,
        timing: TimingMetrics,
        isMocked: Bool
    ) async {
        let entries = LogStore.shared.fetchAll()
        guard let entry = entries.first(where: { $0.effectiveID == id }) else { return }
        entry.responseHeaders   = securityManager.sanitize(headers: responseHeaders)
        entry.responseBody      = securityManager.sanitize(body: responseBody)
        entry.statusCode        = statusCode
        entry.responseSize      = responseSize
        entry.responseContentType = contentType
        entry.timing            = timing
        entry.status            = .completed
        entry.downloadProgress  = 1.0
        entry.isMocked          = isMocked
        LogStore.shared.insert(entry)
        refreshPublisher()
        if configuration.osLogEnabled {
            osLog.debug("← \(statusCode) \(entry.url.absoluteString) \(timing.formattedDuration)")
        }
    }

    func fail(id: UUID, error: Error, timing: TimingMetrics) async {
        let entries = LogStore.shared.fetchAll()
        guard let entry = entries.first(where: { $0.effectiveID == id }) else { return }
        entry.error  = NetworkError(error: error)
        entry.status = .failed
        entry.timing = timing
        LogStore.shared.insert(entry)
        refreshPublisher()
        if configuration.osLogEnabled {
            osLog.error("✕ \(entry.url.absoluteString) – \(error.localizedDescription)")
        }
    }

    func updateProgress(id: UUID, upload: Double?, download: Double?) async {
        let entries = LogStore.shared.fetchAll()
        guard let entry = entries.first(where: { $0.effectiveID == id }) else { return }
        if let u = upload   { entry.uploadProgress   = u }
        if let d = download { entry.downloadProgress = d }
        LogStore.shared.insert(entry)
        refreshPublisher()
    }

    func updateTimingDetail(id: UUID, detail: NetworkTimingDetail) async {
        let entries = LogStore.shared.fetchAll()
        guard let entry = entries.first(where: { $0.effectiveID == id }) else { return }
        entry.timingDetail = detail
        LogStore.shared.insert(entry)
        refreshPublisher()
    }

    func incrementRetry(id: UUID) async {
        let entries = LogStore.shared.fetchAll()
        guard let entry = entries.first(where: { $0.effectiveID == id }) else { return }
        entry.retryCount += 1
        LogStore.shared.insert(entry)
    }

    // MARK: - Public operations

    func clearAll(keepingPinned: Bool = true) async {
        LogStore.shared.deleteAll(keepingPinned: keepingPinned)
        SemanticSearch.shared.clearCache()
        refreshPublisher()
    }

    func setPinned(_ pinned: Bool, id: UUID) async {
        LogStore.shared.setPinned(pinned, id: id)
        refreshPublisher()
    }

    func remove(ids: Set<UUID>) async {
        ids.forEach { LogStore.shared.delete(id: $0) }
        refreshPublisher()
    }

    func allEntries() async -> [NetworkEntry] {
        LogStore.shared.fetchAll().filter { shouldCapture(entry: $0) }
    }

    func allDomains() async -> [String] {
        LogStore.shared.allDomains()
    }

    // MARK: - Private

    private func shouldCapture(entry: NetworkEntry) -> Bool {
        if !configuration.allowedHosts.isEmpty, !configuration.allowedHosts.contains(entry.host) { return false }
        if configuration.ignoredHosts.contains(entry.host) { return false }
        for component in configuration.ignoredPathComponents { if entry.path.contains(component) { return false } }
        return true
    }

    private func refreshPublisher() {
        subject.send(LogStore.shared.fetchAll().filter { shouldCapture(entry: $0) })
    }
}
