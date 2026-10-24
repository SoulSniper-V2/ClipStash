import Combine
import GRDB
import XCTest
@testable import ClipStash

final class ClipRepositoryTests: XCTestCase {
    private func makeRepository() throws -> ClipRepository {
        try ClipRepository(db: AppDatabase(dbQueue: DatabaseQueue()))
    }

    private func clip(_ content: String, timestamp: Date = Date()) -> ClipItem {
        ClipItem(
            id: nil,
            content: content,
            contentType: "text",
            sourceApp: "Test App",
            sourceAppBundleID: "test.app",
            timestamp: timestamp,
            isPinned: false,
            contentHash: content,
            summary: nil,
            aiTags: nil,
            embedding: nil
        )
    }

    func testInsertReturnsIDForImmediateEmbeddingAndDeduplicates() throws {
        let repository = try makeRepository()
        let inserted = try repository.insert(clip("Remember this clip"))
        let id = try XCTUnwrap(inserted.id)
        let embedding = Data([1, 2, 3, 4])
        try repository.updateEmbedding(id: id, data: embedding)
        try repository.togglePin(id: id)

        let later = Date(timeIntervalSinceNow: 60)
        let duplicate = try repository.insert(clip(inserted.content, timestamp: later))
        XCTAssertEqual(duplicate.id, id)
        XCTAssertEqual(duplicate.timestamp.timeIntervalSince1970, later.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertTrue(duplicate.isPinned)
        XCTAssertEqual(duplicate.embedding, embedding)
        XCTAssertEqual(try repository.totalCount(), 1)
    }

    func testFullTextIndexFollowsInsertAndDelete() throws {
        let repository = try makeRepository()
        let saved = try repository.insert(clip("A searchable clipboard item"))
        XCTAssertEqual(try repository.ftsSearch(query: "searchable").map(\.id), [saved.id])
        try repository.delete(id: XCTUnwrap(saved.id))
        XCTAssertTrue(try repository.ftsSearch(query: "searchable").isEmpty)
    }

    func testPunctuationSearchTreatsLikeWildcardsLiterally() throws {
        let repository = try makeRepository()
        let percent = try repository.insert(clip("100% complete"))
        let underscore = try repository.insert(clip("snake_case"))
        let backslash = try repository.insert(clip("folder\\file"))
        _ = try repository.insert(clip("unrelated text"))

        XCTAssertEqual(try repository.search(query: "%").map(\.id), [percent.id])
        XCTAssertEqual(try repository.search(query: "_").map(\.id), [underscore.id])
        XCTAssertEqual(try repository.search(query: "\\").map(\.id), [backslash.id])
    }

    func testRetentionAndClearPreservePinnedClips() throws {
        let repository = try makeRepository()
        let oldDate = Date(timeIntervalSince1970: 100)
        let pinned = try repository.insert(clip("Pinned", timestamp: oldDate))
        try repository.togglePin(id: XCTUnwrap(pinned.id))
        _ = try repository.insert(clip("Expired", timestamp: oldDate))
        let recent = try repository.insert(clip("Recent"))

        try repository.deleteOlderThan(Date(timeIntervalSince1970: 200))
        XCTAssertEqual(Set(try repository.recentClips().map(\.id)), Set([pinned.id, recent.id]))
        try repository.clearAll()
        XCTAssertEqual(try repository.recentClips().map(\.id), [pinned.id])
    }

    func testRunningMigrationsAgainPreservesHistory() throws {
        let queue = try DatabaseQueue()
        let repository = ClipRepository(db: try AppDatabase(dbQueue: queue))
        let saved = try repository.insert(clip("Persistent history"))
        let reopened = ClipRepository(db: try AppDatabase(dbQueue: queue))
        XCTAssertEqual(try reopened.recentClips().map(\.id), [saved.id])
        XCTAssertEqual(try reopened.search(query: "Persistent").map(\.id), [saved.id])
    }

    func testNewerMigrationDoesNotEraseExistingHistory() throws {
        let queue = try DatabaseQueue()
        let repository = ClipRepository(db: try AppDatabase(dbQueue: queue))
        let saved = try repository.insert(clip("Keep history from a newer build"))
        try queue.write { db in
            try db.execute(sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)", arguments: ["future_migration"])
        }

        // An older build may reject the schema, but must never erase the user's clips.
        _ = try? AppDatabase(dbQueue: queue)
        XCTAssertEqual(try repository.recentClips().map(\.id), [saved.id])
    }

    @MainActor
    func testHistoryCountIncludesClipsBeyondVisiblePage() async throws {
        let repository = try makeRepository()
        for index in 0..<101 {
            _ = try repository.insert(clip("Clip \(index)"))
        }
        let model = ClipListViewModel(repository: repository)
        let updated = expectation(description: "Full history count")
        let subscription = model.$totalCount
            .filter { $0 == 101 }
            .first()
            .sink { _ in updated.fulfill() }
        await fulfillment(of: [updated], timeout: 5)
        XCTAssertEqual(model.clips.count, 100)
        subscription.cancel()
    }

    @MainActor
    func testSearchRefreshesAfterPinDeleteAndNewCapture() async throws {
        let repository = try makeRepository()
        let first = try repository.insert(clip("needle first"))
        let model = ClipListViewModel(repository: repository)
        model.searchQuery = "needle"
        await waitForClips(model) { $0.map(\.id) == [first.id] }

        try repository.togglePin(id: XCTUnwrap(first.id))
        await waitForClips(model) { $0.count == 1 && $0[0].isPinned }

        let second = try repository.insert(clip("needle second"))
        await waitForClips(model) { $0.map(\.id) == [first.id, second.id] }

        try repository.delete(id: XCTUnwrap(first.id))
        await waitForClips(model) { $0.map(\.id) == [second.id] }

        try repository.clearAll()
        await waitForClips(model) { $0.isEmpty }
    }

    @MainActor
    func testWhitespaceSearchKeepsReceivingHistory() async throws {
        let repository = try makeRepository()
        let model = ClipListViewModel(repository: repository)
        model.searchQuery = " \n\t "
        let saved = try repository.insert(clip("New clipboard text"))
        await waitForClips(model) { $0.map(\.id) == [saved.id] }
        XCTAssertFalse(model.isSearching)
    }

    @MainActor
    func testSemanticSearchFallsBackToTextAndCanBeReplaced() async throws {
        let repository = try makeRepository()
        let first = try repository.insert(clip("needle first"))
        let second = try repository.insert(clip("different second"))
        let model = ClipListViewModel(repository: repository)
        model.searchQuery = "needle"
        model.toggleSearchMode()
        await waitForClips(model) { $0.map(\.id) == [first.id] }

        model.searchQuery = "different"
        model.toggleSearchMode()
        await waitForClips(model) { $0.map(\.id) == [second.id] }
        XCTAssertFalse(model.isSemanticSearching)
    }

    @MainActor
    private func waitForClips(
        _ model: ClipListViewModel,
        matching predicate: @escaping ([ClipItem]) -> Bool
    ) async {
        let updated = expectation(description: "History observation refresh")
        let subscription = model.$clips
            .filter(predicate)
            .first()
            .sink { _ in updated.fulfill() }
        await fulfillment(of: [updated], timeout: 5)
        subscription.cancel()
    }
}
