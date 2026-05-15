import Foundation
import SQLite3

/// SQLite-backed persistent store for `NetworkEntry` values.
/// All mutations happen on a private serial queue — safe to call from any thread.
final class LogStore: @unchecked Sendable {

    static let shared = LogStore()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.loupe.logstore", qos: .utility)
    private var maxEntries: Int = 500

    // MARK: - Init

    private init() {
        queue.sync { self.openDatabase() }
    }

    func setMaxEntries(_ max: Int) {
        queue.async { self.maxEntries = max }
    }

    // MARK: - Database setup

    private func openDatabase() {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Loupe", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent("log.sqlite").path

        guard sqlite3_open(path, &db) == SQLITE_OK else { return }
        createTable()
        migrateIfNeeded()
    }

    /// Best-effort column additions for older DBs. Errors are ignored because
    /// `ALTER TABLE ADD COLUMN` fails harmlessly when the column already exists.
    private func migrateIfNeeded() {
        sqlite3_exec(db, "ALTER TABLE log_entries ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS log_entries (
            id                  TEXT PRIMARY KEY,
            method              TEXT NOT NULL,
            url                 TEXT NOT NULL,
            request_headers     TEXT,
            request_body        BLOB,
            status_code         INTEGER,
            response_headers    TEXT,
            response_body       BLOB,
            start_time          REAL NOT NULL,
            duration            REAL NOT NULL DEFAULT 0,
            request_size        INTEGER NOT NULL DEFAULT 0,
            response_size       INTEGER NOT NULL DEFAULT 0,
            is_mocked           INTEGER NOT NULL DEFAULT 0,
            timing_data         TEXT,
            error_domain        TEXT,
            error_code          INTEGER,
            error_description   TEXT,
            is_pinned           INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_start_time ON log_entries(start_time DESC);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: - Insert

    func insert(_ entry: NetworkEntry) {
        queue.async { [weak self] in
            self?.performInsert(entry)
            self?.evictIfNeeded()
        }
    }

    private func performInsert(_ entry: NetworkEntry) {
        let sql = """
        INSERT OR REPLACE INTO log_entries
        (id, method, url, request_headers, request_body,
         status_code, response_headers, response_body,
         start_time, duration, request_size, response_size,
         is_mocked, timing_data, error_domain, error_code, error_description, is_pinned)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?);
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        let headersEncoder = JSONEncoder()

        sqlite3_bind_text(stmt, 1,  entry.effectiveID.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2,  entry.method, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3,  entry.url.absoluteString, -1, SQLITE_TRANSIENT)

        if let hData = try? headersEncoder.encode(entry.requestHeaders),
           let hStr = String(data: hData, encoding: .utf8) {
            sqlite3_bind_text(stmt, 4, hStr, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 4)
        }

        if let body = entry.requestBody {
            body.withUnsafeBytes { sqlite3_bind_blob(stmt, 5, $0.baseAddress, Int32(body.count), SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(stmt, 5)
        }

        if let code = entry.statusCode { sqlite3_bind_int(stmt, 6, Int32(code)) } else { sqlite3_bind_null(stmt, 6) }

        if let hData = try? headersEncoder.encode(entry.responseHeaders),
           let hStr = String(data: hData, encoding: .utf8) {
            sqlite3_bind_text(stmt, 7, hStr, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 7)
        }

        if let body = entry.responseBody {
            body.withUnsafeBytes { sqlite3_bind_blob(stmt, 8, $0.baseAddress, Int32(body.count), SQLITE_TRANSIENT) }
        } else {
            sqlite3_bind_null(stmt, 8)
        }

        sqlite3_bind_double(stmt, 9,  entry.timing.startDate.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 10, entry.timing.totalDuration ?? 0)
        sqlite3_bind_int(stmt,    11, Int32(entry.requestBody?.count ?? 0))
        sqlite3_bind_int(stmt,    12, Int32(entry.responseSize))
        sqlite3_bind_int(stmt,    13, entry.isMocked ? 1 : 0)

        if let td = entry.timingDetail,
           let tdData = try? headersEncoder.encode(td),
           let tdStr = String(data: tdData, encoding: .utf8) {
            sqlite3_bind_text(stmt, 14, tdStr, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 14)
        }

        if let err = entry.error {
            sqlite3_bind_text(stmt, 15, err.domain, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt,  16, Int32(err.code))
            sqlite3_bind_text(stmt, 17, err.localizedDescription, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(stmt, 15)
            sqlite3_bind_null(stmt, 16)
            sqlite3_bind_null(stmt, 17)
        }

        sqlite3_bind_int(stmt, 18, entry.isPinned ? 1 : 0)

        sqlite3_step(stmt)
    }

    // MARK: - Fetch

    func fetchAll() -> [NetworkEntry] {
        queue.sync { performFetch(sql: "SELECT * FROM log_entries ORDER BY start_time DESC;") }
    }

    func fetchFiltered(
        methods: Set<String>,
        statusClasses: Set<Int>,
        domains: Set<String>,
        searchText: String,
        maxDuration: TimeInterval?
    ) -> [NetworkEntry] {
        queue.sync {
            var conditions: [String] = []

            if !methods.isEmpty {
                let list = methods.map { "'\($0)'" }.joined(separator: ",")
                conditions.append("method IN (\(list))")
            }
            if !statusClasses.isEmpty {
                let clauses = statusClasses.map { cls -> String in
                    "status_code BETWEEN \(cls * 100) AND \(cls * 100 + 99)"
                }
                conditions.append("(" + clauses.joined(separator: " OR ") + ")")
            }
            if !domains.isEmpty {
                let clauses = domains.map { "url LIKE '%\($0)%'" }
                conditions.append("(" + clauses.joined(separator: " OR ") + ")")
            }
            if !searchText.isEmpty {
                let s = searchText.replacingOccurrences(of: "'", with: "''")
                conditions.append("(url LIKE '%\(s)%' OR method LIKE '%\(s)%')")
            }
            if let max = maxDuration {
                conditions.append("duration <= \(max)")
            }

            let where_ = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
            return performFetch(sql: "SELECT * FROM log_entries \(where_) ORDER BY start_time DESC;")
        }
    }

    private func performFetch(sql: String) -> [NetworkEntry] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        var entries: [NetworkEntry] = []
        let decoder = JSONDecoder()

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let idStr   = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                  let id      = UUID(uuidString: idStr),
                  let method  = sqlite3_column_text(stmt, 1).map({ String(cString: $0) }),
                  let urlStr  = sqlite3_column_text(stmt, 2).map({ String(cString: $0) }),
                  let url     = URL(string: urlStr)
            else { continue }

            var reqHeaders: [String: String] = [:]
            if let hStr = sqlite3_column_text(stmt, 3).map({ String(cString: $0) }),
               let hData = hStr.data(using: .utf8),
               let decoded = try? decoder.decode([String: String].self, from: hData) {
                reqHeaders = decoded
            }

            var reqBody: Data? = nil
            if sqlite3_column_type(stmt, 4) != SQLITE_NULL {
                let bytes = sqlite3_column_blob(stmt, 4)
                let count = sqlite3_column_bytes(stmt, 4)
                if let bytes { reqBody = Data(bytes: bytes, count: Int(count)) }
            }

            let statusCode: Int? = sqlite3_column_type(stmt, 5) != SQLITE_NULL
                ? Int(sqlite3_column_int(stmt, 5)) : nil

            var respHeaders: [String: String] = [:]
            if let hStr = sqlite3_column_text(stmt, 6).map({ String(cString: $0) }),
               let hData = hStr.data(using: .utf8),
               let decoded = try? decoder.decode([String: String].self, from: hData) {
                respHeaders = decoded
            }

            var respBody: Data? = nil
            if sqlite3_column_type(stmt, 7) != SQLITE_NULL {
                let bytes = sqlite3_column_blob(stmt, 7)
                let count = sqlite3_column_bytes(stmt, 7)
                if let bytes { respBody = Data(bytes: bytes, count: Int(count)) }
            }

            let startTime  = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 8))
            let duration   = sqlite3_column_double(stmt, 9)
            let respSize   = Int64(sqlite3_column_int(stmt, 11))
            let isMocked   = sqlite3_column_int(stmt, 12) != 0

            var timingDetail: NetworkTimingDetail? = nil
            if let tdStr = sqlite3_column_text(stmt, 13).map({ String(cString: $0) }),
               let tdData = tdStr.data(using: .utf8),
               let decoded = try? decoder.decode(NetworkTimingDetail.self, from: tdData) {
                timingDetail = decoded
            }

            var networkError: NetworkError? = nil
            if let domain = sqlite3_column_text(stmt, 14).map({ String(cString: $0) }) {
                let code = Int(sqlite3_column_int(stmt, 15))
                let desc = sqlite3_column_text(stmt, 16).map({ String(cString: $0) }) ?? ""
                networkError = NetworkError(domain: domain, code: code, localizedDescription: desc)
            }

            let isPinned: Bool = sqlite3_column_count(stmt) > 17
                ? sqlite3_column_int(stmt, 17) != 0
                : false

            let entry = NetworkEntry(url: url, method: method, requestHeaders: reqHeaders, requestBody: reqBody, id: id)
            entry.id2              = id
            entry.responseHeaders  = respHeaders
            entry.responseBody     = respBody
            entry.statusCode       = statusCode
            entry.responseSize     = respSize
            entry.isMocked         = isMocked
            entry.isPinned         = isPinned
            entry.timingDetail     = timingDetail
            entry.error            = networkError
            entry.status           = statusCode != nil ? .completed : (networkError != nil ? .failed : .pending)

            var timing = TimingMetrics(startDate: startTime)
            timing.endDate = startTime.addingTimeInterval(duration)
            entry.timing = timing

            entries.append(entry)
        }
        return entries
    }

    // MARK: - Delete

    func deleteAll(keepingPinned: Bool = true) {
        queue.async {
            let sql = keepingPinned
                ? "DELETE FROM log_entries WHERE is_pinned = 0;"
                : "DELETE FROM log_entries;"
            sqlite3_exec(self.db, sql, nil, nil, nil)
        }
    }

    func setPinned(_ pinned: Bool, id: UUID) {
        queue.async {
            var stmt: OpaquePointer?
            let sql = "UPDATE log_entries SET is_pinned = ? WHERE id = ?;"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, pinned ? 1 : 0)
            sqlite3_bind_text(stmt, 2, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
    }

    func delete(id: UUID) {
        queue.async {
            var stmt: OpaquePointer?
            let sql = "DELETE FROM log_entries WHERE id = ?;"
            guard sqlite3_prepare_v2(self.db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Eviction

    private func evictIfNeeded() {
        let countSQL = "SELECT COUNT(*) FROM log_entries;"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, countSQL, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_step(stmt)
        let count = Int(sqlite3_column_int(stmt, 0))
        sqlite3_finalize(stmt)

        guard count > maxEntries else { return }
        let excess = count - maxEntries
        sqlite3_exec(db,
            "DELETE FROM log_entries WHERE id IN (SELECT id FROM log_entries ORDER BY start_time ASC LIMIT \(excess));",
            nil, nil, nil)
    }

    // MARK: - Unique domains

    func allDomains() -> [String] {
        queue.sync {
            var domains: [String] = []
            var stmt: OpaquePointer?
            let sql = "SELECT DISTINCT url FROM log_entries ORDER BY start_time DESC;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let urlStr = sqlite3_column_text(stmt, 0).map({ String(cString: $0) }),
                   let host = URL(string: urlStr)?.host {
                    if !domains.contains(host) { domains.append(host) }
                }
            }
            return domains
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
