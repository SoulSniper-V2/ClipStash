import Foundation
import GRDB

/// Manages the SQLite database lifecycle: creation, migrations, and access.
final class AppDatabase {
    /// The GRDB database queue (serialized access).
    let dbQueue: DatabaseQueue

    /// Shared singleton instance.
    static let shared: AppDatabase = {
        do {
            return try AppDatabase()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }()

    private init() throws {
        // Create the Application Support directory if needed
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dbDirectory = appSupportURL.appendingPathComponent("ClipStash", isDirectory: true)
        try fileManager.createDirectory(at: dbDirectory, withIntermediateDirectories: true)

        let dbURL = dbDirectory.appendingPathComponent("history.db")

        // Configure GRDB
        var config = Configuration()
        #if DEBUG
        config.prepareDatabase { db in
            db.trace { print("SQL: \($0)") }
        }
        #endif

        dbQueue = try DatabaseQueue(path: dbURL.path, configuration: config)

        // Run migrations
        try migrator.migrate(dbQueue)
    }

    // MARK: - Migrations

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        #if DEBUG
        // Wipe DB on schema change during development
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        // v1: Core clips table
        migrator.registerMigration("v1_createClipItem") { db in
            try db.create(table: "clipItem") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("content", .text).notNull()
                t.column("contentType", .text).notNull().defaults(to: "text")
                t.column("sourceApp", .text)
                t.column("sourceAppBundleID", .text)
                t.column("timestamp", .datetime).notNull()
                    .indexed()
                t.column("isPinned", .boolean).notNull().defaults(to: false)
                t.column("contentHash", .text).notNull()
                    .indexed()
            }
        }

        // v2: Full-text search index
        migrator.registerMigration("v2_createFTS") { db in
            try db.create(virtualTable: "clipItemFTS", using: FTS5()) { t in
                t.synchronize(withTable: "clipItem")
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("content")
                t.column("sourceApp")
            }
        }

        return migrator
    }
}
