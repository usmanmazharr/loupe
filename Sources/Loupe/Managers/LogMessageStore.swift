import Foundation
import Combine
import OSLog

/// Captures and stores `LogMessage` records — Loupe's "console" feature.
/// Holds a bounded in-memory ring buffer (no SQLite) since logs are noisy and
/// high-volume; surviving across launches isn't a goal.
public actor LogMessageStore {

    public static let shared = LogMessageStore()

    private var buffer: [LogMessage] = []
    private var capacity: Int = 1_000

    private let subject = CurrentValueSubject<[LogMessage], Never>([])
    nonisolated let messagesPublisher: AnyPublisher<[LogMessage], Never>

    /// Sources of automatic capture configured by the host app.
    private var enabledSubsystems: Set<String> = []
    private var pollingTask: Task<Void, Never>?

    private init() {
        messagesPublisher = subject.eraseToAnyPublisher()
    }

    // MARK: - Configuration

    public func setCapacity(_ n: Int) { capacity = max(50, n) }

    // MARK: - Manual API

    /// Append a single log line. Call this from your code anywhere you want
    /// the message to appear in Loupe's console.
    public func log(_ message: String,
                    level: LogMessage.Level = .info,
                    subsystem: String = "",
                    category: String = "") {
        let entry = LogMessage(level: level, subsystem: subsystem,
                               category: category, message: message)
        append(entry)
    }

    public func clearAll() {
        buffer.removeAll()
        subject.send([])
    }

    public func allMessages() -> [LogMessage] { buffer }

    // MARK: - OSLogStore polling (iOS 15+ / macOS 12+)

    /// Pull recent entries from the unified log store every `interval` seconds
    /// for the supplied subsystems. Pass an empty set to disable.
    public func startMirroring(subsystems: Set<String>, interval: TimeInterval = 2.0) {
        enabledSubsystems = subsystems
        pollingTask?.cancel()
        guard !subsystems.isEmpty else { return }

        pollingTask = Task { [weak self] in
            guard let self else { return }
            var lastSeen = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                let cutoff = lastSeen
                lastSeen = Date()
                await self.pullOSLog(since: cutoff)
            }
        }
    }

    public func stopMirroring() {
        pollingTask?.cancel()
        pollingTask = nil
        enabledSubsystems.removeAll()
    }

    private func pullOSLog(since: Date) async {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }
        guard let store = try? OSLogStore(scope: .currentProcessIdentifier) else { return }
        let position = store.position(date: since)
        guard let entries = try? store.getEntries(at: position) else { return }

        for raw in entries {
            guard let entry = raw as? OSLogEntryLog else { continue }
            if !enabledSubsystems.isEmpty,
               !enabledSubsystems.contains(entry.subsystem) { continue }
            let msg = LogMessage(
                timestamp: entry.date,
                level: mapLevel(entry.level),
                subsystem: entry.subsystem,
                category: entry.category,
                message: entry.composedMessage
            )
            append(msg)
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    private func mapLevel(_ l: OSLogEntryLog.Level) -> LogMessage.Level {
        switch l {
        case .debug:    return .debug
        case .info:     return .info
        case .notice:   return .notice
        case .error:    return .error
        case .fault:    return .fault
        case .undefined: return .info
        @unknown default: return .info
        }
    }

    // MARK: - Internal

    private func append(_ message: LogMessage) {
        buffer.append(message)
        if buffer.count > capacity {
            buffer.removeFirst(buffer.count - capacity)
        }
        subject.send(buffer)
    }
}
