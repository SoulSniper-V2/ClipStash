import Foundation
import GRDB

/// Data access layer for clipboard items.
final class ClipRepository {
    private let db: AppDatabase

    init(db: AppDatabase = .shared) {
        self.db = db
    }

    // MARK: - Insert

    /// Insert a new clip, deduplicating by content hash.
    /// If a duplicate exists, update its timestamp to bubble it up.
    @discardableResult
    func insert(_ clip: ClipItem) throws -> ClipItem {
        try db.dbQueue.write { db in
            // Check for existing clip with same hash
            if var existing = try ClipItem
                .filter(ClipItem.Columns.contentHash == clip.contentHash)
                .fetchOne(db) {
                // Update timestamp to bring it to the top
                existing.timestamp = clip.timestamp
                existing.sourceApp = clip.sourceApp ?? existing.sourceApp
                existing.sourceAppBundleID = clip.sourceAppBundleID ?? existing.sourceAppBundleID
                try existing.update(db)
                return existing
            } else {
                var newClip = clip
                try newClip.insert(db)
                return newClip  // newClip.id is now set by GRDB
            }
        }
    }

    // MARK: - Fetch

    /// Fetch the most recent clips, pinned items first.
    func recentClips(limit: Int = 50) throws -> [ClipItem] {
        try db.dbQueue.read { db in
            try ClipItem
                .order(
                    ClipItem.Columns.isPinned.desc,
                    ClipItem.Columns.timestamp.desc
                )
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Full-text search using FTS5.
    func search(query: String) throws -> [ClipItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try recentClips()
        }

        return try db.dbQueue.read { db in
            // Use FTS5 match, with the pattern trimmed and cleaned
            let pattern = FTS5Pattern(matchingAnyTokenIn: query)
            if pattern != nil {
                return try ClipItem
                    .joining(required: ClipItem.hasOne(
                        ClipItem.self, // dummy — we use raw SQL for FTS join
                        using: ForeignKey(["rowid"], to: ["id"])
                    ))
                    .fetchAll(db)
            }

            // Fallback: LIKE search
            let likePattern = "%\(query)%"
            return try ClipItem
                .filter(ClipItem.Columns.content.like(likePattern))
                .order(
                    ClipItem.Columns.isPinned.desc,
                    ClipItem.Columns.timestamp.desc
                )
                .limit(50)
                .fetchAll(db)
        }
    }

    /// Search using raw FTS5 SQL for reliability.
    func ftsSearch(query: String) throws -> [ClipItem] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return try recentClips()
        }

        let sql = """
            SELECT clipItem.*
            FROM clipItem
            JOIN clipItemFTS ON clipItemFTS.rowid = clipItem.id
            WHERE clipItemFTS MATCH ?
            ORDER BY clipItem.isPinned DESC, rank
            LIMIT 50
        """

        return try db.dbQueue.read { db in
            try ClipItem.fetchAll(db, sql: sql, arguments: [query])
        }
    }

    // MARK: - Update

    /// Toggle the pinned state of a clip.
    func togglePin(id: Int64) throws {
        try db.dbQueue.write { db in
            if var clip = try ClipItem.fetchOne(db, id: id) {
                clip.isPinned.toggle()
                try clip.update(db)
            }
        }
    }

    // MARK: - Delete

    /// Delete a single clip by ID.
    func delete(id: Int64) throws {
        try db.dbQueue.write { db in
            _ = try ClipItem.deleteOne(db, id: id)
        }
    }

    /// Delete all non-pinned clips.
    func clearAll() throws {
        try db.dbQueue.write { db in
            _ = try ClipItem
                .filter(ClipItem.Columns.isPinned == false)
                .deleteAll(db)
        }
    }

    /// Delete clips older than a given date.
    func deleteOlderThan(_ date: Date) throws {
        try db.dbQueue.write { db in
            _ = try ClipItem
                .filter(ClipItem.Columns.isPinned == false)
                .filter(ClipItem.Columns.timestamp < date)
                .deleteAll(db)
        }
    }

    // MARK: - Observation

    /// Live observation of recent clips for SwiftUI.
    func recentClipsObservation(limit: Int = 50) -> ValueObservation<ValueReducers.Fetch<[ClipItem]>> {
        ValueObservation.tracking { db in
            try ClipItem
                .order(
                    ClipItem.Columns.isPinned.desc,
                    ClipItem.Columns.timestamp.desc
                )
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Total clip count.
    func totalCount() throws -> Int {
        try db.dbQueue.read { db in
            try ClipItem.fetchCount(db)
        }
    }

    // MARK: - AI Features

    /// Update the AI-generated summary for a clip.
    func updateSummary(id: Int64, summary: String) throws {
        try db.dbQueue.write { db in
            if var clip = try ClipItem.fetchOne(db, id: id) {
                clip.summary = summary
                try clip.update(db)
            }
        }
    }

    /// Update the AI-generated tags for a clip.
    func updateTags(id: Int64, tags: [String]) throws {
        try db.dbQueue.write { db in
            if var clip = try ClipItem.fetchOne(db, id: id) {
                clip.aiTags = tags.joined(separator: ",")
                try clip.update(db)
            }
        }
    }

    /// Mark a clip as embedded by storing its vector.
    func updateEmbedding(id: Int64, data: Data) throws {
        try db.dbQueue.write { db in
            if var clip = try ClipItem.fetchOne(db, id: id) {
                clip.embedding = data
                try clip.update(db)
            }
        }
    }

    /// Fetch clips that haven't been embedded yet (for background processing).
    func unembeddedClips(limit: Int = 50) throws -> [ClipItem] {
        try db.dbQueue.read { db in
            try ClipItem
                .filter(ClipItem.Columns.embedding == nil)
                .order(ClipItem.Columns.timestamp.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Fetch clips that haven't been summarized yet (long content only).
    func unsummarizedClips(limit: Int = 20) throws -> [ClipItem] {
        try db.dbQueue.read { db in
            try ClipItem
                .filter(ClipItem.Columns.summary == nil)
                .filter(length(ClipItem.Columns.content) > 200)
                .order(ClipItem.Columns.timestamp.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Fetch a clip by ID.
    func fetchClip(id: Int64) throws -> ClipItem? {
        try db.dbQueue.read { db in
            try ClipItem.fetchOne(db, id: id)
        }
    }
}
