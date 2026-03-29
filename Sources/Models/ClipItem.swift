import Foundation
import GRDB

/// A single clipboard history entry stored in SQLite.
struct ClipItem: Codable, Identifiable, Equatable, Hashable {
    /// Auto-incremented row ID.
    var id: Int64?
    /// The clipboard text content.
    var content: String
    /// Detected content type (text, url, code, etc.).
    var contentType: String
    /// Display name of the source application.
    var sourceApp: String?
    /// Bundle identifier of the source application.
    var sourceAppBundleID: String?
    /// When the clip was captured.
    var timestamp: Date
    /// Whether the user has pinned this clip.
    var isPinned: Bool
    /// SHA-256 hash of content for deduplication.
    var contentHash: String
    /// AI-generated one-line summary (nil until generated).
    var summary: String?
    /// AI-generated tags, comma-separated (nil until generated).
    var aiTags: String?
    /// CoreML semantic sentence embedding (NLEmbedding).
    var embedding: Data?

    /// Computed helper to get back the native Float array.
    var embeddingVector: [Float]? {
        guard let data = embedding else { return nil }
        return EmbeddingService.shared.dataToVector(data)
    }

    /// Computed helper to extract standard tags.
    var aiTagList: [String] {
        aiTags?.split(separator: ",").map(String.init) ?? []
    }

    /// Parsed content type enum.
    var type: ContentType {
        ContentType(rawValue: contentType) ?? .other
    }

    /// Preview text: first 200 chars, trimmed.
    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 200 { return trimmed }
        return String(trimmed.prefix(200)) + "…"
    }

    /// Number of lines in the content.
    var lineCount: Int {
        content.components(separatedBy: .newlines).count
    }

    /// Character count.
    var charCount: Int {
        content.count
    }
}

// MARK: - GRDB Record Conformance

extension ClipItem: FetchableRecord, PersistableRecord {
    static let databaseTableName = "clipItem"

    /// Define the columns for type-safe queries.
    enum Columns: String, ColumnExpression {
        case id, content, contentType, sourceApp
        case sourceAppBundleID, timestamp, isPinned, contentHash
        case summary, aiTags, embedding
    }

    /// Let GRDB auto-generate the ID on insert.
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
