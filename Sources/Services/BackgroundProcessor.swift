import Foundation

/// Replaces the old AIProcessor. Runs purely natively.
/// - Embeds clips in the background using `EmbeddingService` (always runs).
final class BackgroundProcessor {

    static let shared = BackgroundProcessor()

    private let repository: ClipRepository
    private let queue = DispatchQueue(label: "com.clipstash.ai", qos: .background)
    private var timer: Timer?
    private let batchSize = 10
    private let interval: TimeInterval = 30
    private var isProcessing = false

    init(repository: ClipRepository = ClipRepository()) {
        self.repository = repository
    }

    /// Run immediately on launch, then periodically.
    func start() {
        // Initial process
        queue.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.processBacklog()
        }

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.processBacklog()
        }
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Called immediately when a new clip arrives to skip the 30s wait.
    func processImmediately(_ clip: ClipItem) {
        queue.async { [weak self] in
            self?.embedAndEnrich(clip)
        }
    }

    // MARK: - Private

    private func processBacklog() {
        guard !isProcessing else { return }
        isProcessing = true
        
        queue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            do {
                self.pruneExpiredClipsIfNeeded()

                // 1. Fetch unembedded clips
                let clips = try self.repository.unembeddedClips(limit: self.batchSize)
                if !clips.isEmpty {
                    print("BackgroundProcessor: Processing \(clips.count) unembedded clips")
                    for clip in clips {
                        self.embedAndEnrich(clip)
                        // Sleep slightly to yield resources if needed, though NLEmbedding is fast
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }

            } catch {
                print("BackgroundProcessor error: \(error)")
            }
        }
    }

    /// Core processing for a single clip.
    private func embedAndEnrich(_ clip: ClipItem) {
        guard let id = clip.id else { return }

        // 1. Embed Locally (Always runs natively)
        // If it doesn't have an embedding, generate one.
        if clip.embedding == nil {
            if let vector = EmbeddingService.shared.embedLocally(clip.content) {
                let data = EmbeddingService.shared.vectorToData(vector)
                try? repository.updateEmbedding(id: id, data: data)
            }
        }
    }

    /// Applies the current retention policy to non-pinned history.
    private func pruneExpiredClipsIfNeeded() {
        guard let cutoffDate = HistoryRetentionPolicy.current.cutoffDate else { return }

        do {
            try repository.deleteOlderThan(cutoffDate)
        } catch {
            print("BackgroundProcessor retention cleanup error: \(error)")
        }
    }
}
