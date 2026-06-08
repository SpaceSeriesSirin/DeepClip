import Foundation
import GRDB

/// Owns the GRDB `DatabaseQueue` and the schema migrations.
final class AppDatabase {
    let dbQueue: DatabaseQueue

    init(_ dbQueue: DatabaseQueue) throws {
        self.dbQueue = dbQueue
        try migrator.migrate(dbQueue)
    }

    /// Location of the on-disk database file.
    static func defaultURL() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("ClipboardManager", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("clipboard.sqlite")
    }

    /// Opens (creating if needed) the shared on-disk database.
    static func makeShared() throws -> AppDatabase {
        let url = try defaultURL()
        var config = Configuration()
        config.foreignKeysEnabled = true
        let dbQueue = try DatabaseQueue(path: url.path, configuration: config)
        let db = try AppDatabase(dbQueue)
        AppLogger.database.info("Database opened at \(url.path, privacy: .public)")
        return db
    }

    /// In-memory database, handy for tests / previews.
    static func makeInMemory() throws -> AppDatabase {
        let dbQueue = try DatabaseQueue()
        return try AppDatabase(dbQueue)
    }

    /// Current size of the database file on disk, in bytes.
    func fileSize() -> Int64 {
        guard let url = try? Self.defaultURL(),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return 0
        }
        return size
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = false
        #endif

        migrator.registerMigration("createSchema") { db in
            try db.create(table: "clipboardItem") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("contentType", .text).notNull()
                t.column("textContent", .text)
                t.column("imageData", .blob)
                t.column("urlDomain", .text)
                t.column("sourceApp", .text)
                t.column("title", .text)
                t.column("summary", .text)
                t.column("embedding", .blob)
                t.column("isPinned", .integer).notNull().defaults(to: false)
                t.column("isDuplicate", .integer).notNull().defaults(to: false)
                t.column("capturedAt", .datetime).notNull()
                t.column("expiresAt", .datetime)
                t.column("metadata", .text)
            }
            try db.create(index: "idx_contentType", on: "clipboardItem", columns: ["contentType"])
            try db.create(index: "idx_urlDomain", on: "clipboardItem", columns: ["urlDomain"])
            try db.create(index: "idx_capturedAt", on: "clipboardItem", columns: ["capturedAt"])
            try db.create(index: "idx_isPinned", on: "clipboardItem", columns: ["isPinned"])

            try db.create(table: "setting") { t in
                t.column("key", .text).primaryKey()
                t.column("value", .text).notNull()
            }
        }

        return migrator
    }
}
