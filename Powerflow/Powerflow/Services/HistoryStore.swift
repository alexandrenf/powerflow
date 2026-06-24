import Foundation
import SQLite3
import Observation

@MainActor
@Observable
final class HistoryStore {
    private(set) var sessions: [ChargingHistory] = []
    var selectedSession: ChargingHistory?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private var db: OpaquePointer?
    private var dbPath: String?

    init() {
        openDatabase()
        Task { await refresh() }
    }

    func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        guard let db else {
            errorMessage = "Database unavailable"
            return
        }

        var results: [ChargingHistory] = []
        let sql = """
        SELECT id, from_level, end_level, charging_time, timestamp, name, udid, is_remote, adapter_name
        FROM charging_histories ORDER BY timestamp DESC
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            errorMessage = String(cString: sqlite3_errmsg(db))
            return
        }
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            results.append(
                ChargingHistory(
                    id: sqlite3_column_int64(statement, 0),
                    fromLevel: sqlite3_column_int64(statement, 1),
                    endLevel: sqlite3_column_int64(statement, 2),
                    chargingTime: sqlite3_column_int64(statement, 3),
                    timestamp: sqlite3_column_int64(statement, 4),
                    name: String(cString: sqlite3_column_text(statement, 5)),
                    udid: String(cString: sqlite3_column_text(statement, 6)),
                    isRemote: sqlite3_column_int64(statement, 7) != 0,
                    adapterName: String(cString: sqlite3_column_text(statement, 8))
                )
            )
        }

        sessions = results
        errorMessage = nil
    }

    func loadDetail(for id: Int64) async -> ChargingHistoryDetail? {
        guard let db else { return nil }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT detail FROM charging_histories WHERE id = ?", -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let blob = sqlite3_column_blob(statement, 0) else {
            return nil
        }
        let length = Int(sqlite3_column_bytes(statement, 0))
        let data = Data(bytes: blob, count: length)
        return try? JSONDecoder().decode(ChargingHistoryDetail.self, from: data)
    }

    func saveSession(stages: [ChargingHistoryStageInput], deviceName: String) async {
        guard let db, let first = stages.first, let last = stages.last else { return }

        let avg = stages
            .map(\.data.data)
            .reduce(NormalizedData(), +)
            .divided(by: Float(stages.count))
        let peak = stages
            .map(\.data.data)
            .reduce(NormalizedData()) { $0.mergedMax(with: $1) }

        let detail = ChargingHistoryDetail(
            avg: avg,
            peak: peak,
            curve: stages.map(\.data),
            raw: stages.map(\.raw)
        )

        guard let detailData = try? JSONEncoder().encode(detail) else { return }

        let duration = last.data.lastUpdate - first.data.lastUpdate
        let adapterName = last.data.adapterName ?? "Unknown"

        var statement: OpaquePointer?
        let sql = """
        INSERT INTO charging_histories
        (from_level, end_level, charging_time, timestamp, detail, name, udid, is_remote, adapter_name)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(first.data.batteryLevel))
        sqlite3_bind_int64(statement, 2, Int64(last.data.batteryLevel))
        sqlite3_bind_int64(statement, 3, duration)
        sqlite3_bind_int64(statement, 4, first.data.lastUpdate)
        detailData.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, 5, buffer.baseAddress, Int32(buffer.count), nil)
        }
        sqlite3_bind_text(statement, 6, deviceName, -1, nil)
        sqlite3_bind_text(statement, 7, "local", -1, nil)
        sqlite3_bind_int64(statement, 8, 0)
        sqlite3_bind_text(statement, 9, adapterName, -1, nil)
        sqlite3_step(statement)
        await refresh()
        NotificationCenter.default.post(name: .historyRecorded, object: nil)
    }

    func deleteSession(id: Int64) async {
        guard let db else { return }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "DELETE FROM charging_histories WHERE id = ?", -1, &statement, nil) == SQLITE_OK else {
            return
        }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, id)
        sqlite3_step(statement)
        if selectedSession?.id == id {
            selectedSession = nil
        }
        await refresh()
    }

    private func openDatabase() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let candidates = [
            appSupport.appendingPathComponent("Powerflow", isDirectory: true),
            appSupport.appendingPathComponent("powerflow", isDirectory: true),
        ]

        var dbURL: URL?
        for candidate in candidates {
            let path = candidate.appendingPathComponent("db.sqlite")
            if FileManager.default.fileExists(atPath: path.path) {
                dbURL = path
                break
            }
            if dbURL == nil {
                try? FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
                dbURL = path
            }
        }

        guard let dbURL else { return }
        dbPath = dbURL.path

        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            db = nil
            return
        }

        let createSQL = """
        CREATE TABLE IF NOT EXISTS charging_histories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            from_level INTEGER NOT NULL,
            end_level INTEGER NOT NULL,
            charging_time INTEGER NOT NULL,
            timestamp INTEGER NOT NULL,
            detail BLOB NOT NULL,
            name TEXT NOT NULL DEFAULT '',
            udid TEXT NOT NULL DEFAULT '',
            is_remote INTEGER NOT NULL DEFAULT 0,
            adapter_name TEXT NOT NULL DEFAULT 'Unknown'
        );
        """
        sqlite3_exec(db, createSQL, nil, nil, nil)
    }
}

struct ChargingHistoryStageInput {
    let data: NormalizedResource
    let raw: String
}

private extension NormalizedData {
    static func + (lhs: NormalizedData, rhs: NormalizedData) -> NormalizedData {
        NormalizedData(
            systemIn: lhs.systemIn + rhs.systemIn,
            systemLoad: lhs.systemLoad + rhs.systemLoad,
            batteryPower: lhs.batteryPower + rhs.batteryPower,
            adapterPower: lhs.adapterPower + rhs.adapterPower,
            efficiencyLoss: lhs.efficiencyLoss + rhs.efficiencyLoss,
            brightnessPower: lhs.brightnessPower + rhs.brightnessPower,
            heatpipePower: lhs.heatpipePower + rhs.heatpipePower,
            batteryLevel: lhs.batteryLevel + rhs.batteryLevel,
            absoluteBatteryLevel: lhs.absoluteBatteryLevel + rhs.absoluteBatteryLevel,
            temperature: lhs.temperature + rhs.temperature,
            adapterWatts: lhs.adapterWatts + rhs.adapterWatts,
            adapterVoltage: lhs.adapterVoltage + rhs.adapterVoltage,
            adapterAmperage: lhs.adapterAmperage + rhs.adapterAmperage
        )
    }

    func divided(by count: Float) -> NormalizedData {
        guard count > 0 else { return self }
        return self / count
    }
}
