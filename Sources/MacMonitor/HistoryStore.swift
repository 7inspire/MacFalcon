import Foundation
import CSQLite

struct HistoricalProcess: Codable, Identifiable {
    var id: Int32
    var name: String
    var cpu: Double
    var memory: UInt64
}
struct HistoricalRecord: Identifiable {
    var id: Int64
    var time: Date
    var cpu: Double
    var memory: Double
    var download: Double
    var upload: Double
    var processes: [HistoricalProcess]
}

// Used exclusively by Monitor's serial utility queue.
final class HistoryStore: @unchecked Sendable {
    private var db: OpaquePointer?
    private(set) var error: String?
    private var lastSaved: TimeInterval = 0
    init(databaseURL: URL? = nil) {
        do {
            let url: URL
            if let databaseURL { url = databaseURL }
            else {
                let dir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("MacFalcon", isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                url = dir.appendingPathComponent("history.sqlite3")
                let legacy = dir.deletingLastPathComponent().appendingPathComponent("Pulse/history.sqlite3")
                try Self.migrateDatabase(from: legacy, to: url)
            }
            guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else { throw storeError() }
            try execute("PRAGMA journal_mode=WAL; CREATE TABLE IF NOT EXISTS samples (time INTEGER PRIMARY KEY, cpu REAL NOT NULL, memory REAL NOT NULL, download REAL NOT NULL, upload REAL NOT NULL, processes TEXT NOT NULL);")
            var query: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT COALESCE(MAX(time), 0) FROM samples", -1, &query, nil) == SQLITE_OK, sqlite3_step(query) == SQLITE_ROW { lastSaved = sqlite3_column_double(query, 0) }
            sqlite3_finalize(query)
        } catch { self.error = error.localizedDescription }
    }
    static func migrateDatabase(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: destination.path), fm.fileExists(atPath: source.path) else { return }
        let temp = destination.deletingLastPathComponent().appendingPathComponent(".history-migration-\(UUID().uuidString).sqlite3")
        defer { try? fm.removeItem(at: temp) }
        var input: OpaquePointer?, output: OpaquePointer?
        defer { if let input { sqlite3_close(input) }; if let output { sqlite3_close(output) } }
        guard sqlite3_open_v2(source.path, &input, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              sqlite3_open_v2(temp.path, &output, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil) == SQLITE_OK,
              let backup = sqlite3_backup_init(output, "main", input, "main") else {
            throw NSError(domain: "MacFalcon.HistoryMigration", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not open the previous history database"])
        }
        let result = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard result == SQLITE_DONE && finish == SQLITE_OK else {
            throw NSError(domain: "MacFalcon.HistoryMigration", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "Could not copy the previous history database"])
        }
        sqlite3_close(output); output = nil
        do { try fm.moveItem(at: temp, to: destination) }
        catch { if !fm.fileExists(atPath: destination.path) { throw error } }
    }
    private func storeError() -> NSError { NSError(domain: "MacFalcon.History", code: Int(sqlite3_errcode(db)), userInfo: [NSLocalizedDescriptionKey: db.map { String(cString: sqlite3_errmsg($0)) } ?? tr("无法打开历史数据库")]) }
    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw storeError() }
    }
    func save(_ snapshot: Snapshot) {
        guard error == nil, db != nil, snapshot.sampledAt.timeIntervalSince1970 - lastSaved >= 60 else { return }
        let top = snapshot.processes.sorted { $0.cpu > $1.cpu }.prefix(5).map { HistoricalProcess(id: $0.id, name: $0.name, cpu: $0.cpu, memory: $0.memory) }
        do {
            let json = String(data: try JSONEncoder().encode(top), encoding: .utf8) ?? "[]"
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO samples VALUES (?, ?, ?, ?, ?, ?)", -1, &statement, nil) == SQLITE_OK else { throw storeError() }
            defer { sqlite3_finalize(statement) }
            let timestamp = Int64(snapshot.sampledAt.timeIntervalSince1970)
            sqlite3_bind_int64(statement, 1, timestamp)
            sqlite3_bind_double(statement, 2, snapshot.cpu)
            let m = snapshot.memory
            sqlite3_bind_double(statement, 3, m.total > 0 ? min(100, Double(m.active + m.wired + m.compressed) / Double(m.total) * 100) : 0)
            sqlite3_bind_double(statement, 4, snapshot.download)
            sqlite3_bind_double(statement, 5, snapshot.upload)
            _ = json.withCString { sqlite3_bind_text(statement, 6, $0, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self)) }
            guard sqlite3_step(statement) == SQLITE_DONE else { throw storeError() }
            lastSaved = Double(timestamp)
            try execute("DELETE FROM samples WHERE time < \(timestamp - 7 * 24 * 60 * 60)")
        } catch { self.error = error.localizedDescription }
    }
    func clear() {
        guard error == nil, db != nil else { return }
        do { try execute("DELETE FROM samples; PRAGMA wal_checkpoint(TRUNCATE);"); lastSaved = 0 }
        catch { self.error = error.localizedDescription }
    }
    func load(hours: Int) -> [HistoricalRecord] {
        guard error == nil, db != nil else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT time,cpu,memory,download,upload,processes FROM samples WHERE time >= ? ORDER BY time DESC LIMIT 10080", -1, &statement, nil) == SQLITE_OK else { error = storeError().localizedDescription; return [] }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, Int64(Date().timeIntervalSince1970) - Int64(hours * 3600))
        var rows: [HistoricalRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let time = sqlite3_column_int64(statement, 0)
            let text = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? "[]"
            let processes = (try? JSONDecoder().decode([HistoricalProcess].self, from: Data(text.utf8))) ?? []
            rows.append(HistoricalRecord(id: time, time: Date(timeIntervalSince1970: Double(time)), cpu: sqlite3_column_double(statement, 1), memory: sqlite3_column_double(statement, 2), download: sqlite3_column_double(statement, 3), upload: sqlite3_column_double(statement, 4), processes: processes))
        }
        return rows
    }
    deinit { sqlite3_close(db) }
}
