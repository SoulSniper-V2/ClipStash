import AppKit
import Combine
import Foundation
import GRDB

/// Drives the popover clip list UI with live database observation and search.
@MainActor
final class ClipListViewModel: ObservableObject {
    // MARK: - Published State

    @Published var clips: [ClipItem] = []
    @Published var searchQuery: String = ""
    @Published var isSearching: Bool = false
    @Published var totalCount: Int = 0
    @Published var selectedClipID: Int64?

    // MARK: - Dependencies

    private let repository: ClipRepository
    private var observation: AnyDatabaseCancellable?
    private var searchDebounce: AnyCancellable?

    init(repository: ClipRepository = ClipRepository()) {
        self.repository = repository
        startObservation()
        setupSearchDebounce()
    }

    // MARK: - Live Observation

    /// Start observing the database for real-time UI updates.
    private func startObservation() {
        let observation = repository.recentClipsObservation(limit: 100)
        self.observation = observation.start(
            in: AppDatabase.shared.dbQueue,
            onError: { error in
                print("ClipListViewModel: observation error: \(error)")
            },
            onChange: { [weak self] (clips: [ClipItem]) in
                Task { @MainActor in
                    guard let self = self else { return }
                    if self.searchQuery.isEmpty {
                        self.clips = clips
                    }
                    self.totalCount = clips.count
                }
            }
        )
    }

    // MARK: - Search

    /// Debounce search queries to avoid spamming the database.
    private func setupSearchDebounce() {
        searchDebounce = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { @MainActor in
                    self?.performSearch(query: query)
                }
            }
    }

    private func performSearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            isSearching = false
            // Re-fetch from observation (it'll push the latest)
            do {
                clips = try repository.recentClips(limit: 100)
            } catch {
                print("ClipListViewModel: fetch error: \(error)")
            }
            return
        }

        isSearching = true

        do {
            // Try FTS5 first, fall back to LIKE
            let results = try repository.ftsSearch(query: trimmed)
            if results.isEmpty {
                // Fallback: plain LIKE search
                clips = try repository.search(query: trimmed)
            } else {
                clips = results
            }
        } catch {
            // If FTS fails (bad query syntax), fall back to LIKE
            do {
                clips = try repository.search(query: trimmed)
            } catch {
                print("ClipListViewModel: search error: \(error)")
            }
        }
    }

    // MARK: - Actions

    /// Copy a clip's content back to the system clipboard.
    func copyToClipboard(_ clip: ClipItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(clip.content, forType: .string)
    }

    /// Delete a clip.
    func deleteClip(_ clip: ClipItem) {
        guard let id = clip.id else { return }
        do {
            try repository.delete(id: id)
        } catch {
            print("ClipListViewModel: delete error: \(error)")
        }
    }

    /// Toggle pin state.
    func togglePin(_ clip: ClipItem) {
        guard let id = clip.id else { return }
        do {
            try repository.togglePin(id: id)
        } catch {
            print("ClipListViewModel: pin error: \(error)")
        }
    }

    /// Clear all non-pinned clips.
    func clearAll() {
        do {
            try repository.clearAll()
        } catch {
            print("ClipListViewModel: clearAll error: \(error)")
        }
    }

    /// Navigate selection up/down for keyboard nav.
    func moveSelection(direction: Int) {
        guard !clips.isEmpty else { return }

        if let currentID = selectedClipID,
           let currentIndex = clips.firstIndex(where: { $0.id == currentID }) {
            let newIndex = max(0, min(clips.count - 1, currentIndex + direction))
            selectedClipID = clips[newIndex].id
        } else {
            // Nothing selected — select first
            selectedClipID = clips.first?.id
        }
    }

    /// Copy and dismiss: copy the currently selected clip.
    func copySelectedAndDismiss() -> Bool {
        guard let selectedID = selectedClipID,
              let clip = clips.first(where: { $0.id == selectedID }) else {
            return false
        }
        copyToClipboard(clip)
        return true
    }
}
