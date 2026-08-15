import Foundation
import SQLite3

struct ExpoLegacyRecentSearchImporter: LegacyRecentSearchImporting {
    let databaseURL: URL

    init(databaseURL: URL = Self.defaultDatabaseURL) {
        self.databaseURL = databaseURL
    }

    static var defaultDatabaseURL: URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("SQLite/ExpoSQLiteStorage", isDirectory: false)
    }

    func load() -> [SearchResult] {
        guard FileManager.default.fileExists(atPath: databaseURL.path) else { return [] }

        var database: OpaquePointer?
        let openStatus = databaseURL.path.withCString { path in
            sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil)
        }
        guard openStatus == SQLITE_OK, let database else {
            if let database { sqlite3_close(database) }
            return []
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let prepareStatus = sqlite3_prepare_v2(
            database,
            "SELECT value FROM storage WHERE key = ? LIMIT 1;",
            -1,
            &statement,
            nil
        )
        guard prepareStatus == SQLITE_OK, let statement else { return [] }
        defer { sqlite3_finalize(statement) }

        let bindStatus = RecentSearchStorage.key.withCString { key in
            sqlite3_bind_text(statement, 1, key, -1, nil)
        }
        guard bindStatus == SQLITE_OK, sqlite3_step(statement) == SQLITE_ROW,
              let value = sqlite3_column_text(statement, 0)
        else { return [] }

        return parseRecentSearches(Data(String(cString: value).utf8))
    }
}
