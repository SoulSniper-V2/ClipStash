import Foundation

/// Background service that processes clips for AI features:
/// - Generates embeddings for semantic search
/// - Generates summaries for long content
/// - Auto-tags clips
///
/// Runs lazily — processes clips in batches on a background queue,
/// triggered by new clip events or periodically.
final class AIProcessor {
    private let llm = LLMService.shared
    private let repository: ClipRepository
    private var processingTimer: Timer?
    private var isProcessing = false

    /// Whether AI features are available (llm installed).
    var isAvailable: Bool { llm.isInstalled }

    init(repository: ClipRepository = ClipRepository()) {
        self.repository = repository
    }

    // MARK: - Lifecycle

    /// Start the background processor. Runs every 30 seconds.
    func start() {
        guard llm.isInstalled else {
            print("AIProcessor: llm not installed, AI features disabled")
            return
        }

        // Initial processing after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.processBacklog()
        }

        // Periodic processing
        processingTimer = Timer.scheduledTimer(
            withTimeInterval: 30,
            repeats: true
        ) { [weak self] _ in
            self?.processBacklog()
        }
        if let timer = processingTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Stop the background processor.
    func stop() {
        processingTimer?.invalidate()
        processingTimer = nil
    }

    // MARK: - Triggered Processing

    /// Called when a new clip is captured — kick off AI processing for it.
    func processNewClip(_ clip: ClipItem) {
        guard llm.isInstalled, let clipID = clip.id else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }

            // Embed the clip for semantic search
            let embedded = await self.llm.embedClip(id: clipID, content: clip.content)
            if embedded {
                try? self.repository.markEmbedded(id: clipID)
            }

            // Generate summary for long content
            if clip.content.count > 200 {
                if let summary = await self.llm.generateSummary(for: clip.content) {
                    try? self.repository.updateSummary(id: clipID, summary: summary)
                }
            }

            // Auto-tag
            let tags = await self.llm.autoTag(content: clip.content)
            if !tags.isEmpty {
                try? self.repository.updateTags(id: clipID, tags: tags)
            }
        }
    }

    // MARK: - Backlog Processing

    /// Process any un-embedded or un-summarized clips from the backlog.
    private func processBacklog() {
        guard llm.isInstalled, !isProcessing else { return }
        isProcessing = true

        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            // Batch embed un-embedded clips
            await self.processUnembeddedClips()

            // Generate summaries for long un-summarized clips
            await self.processUnsummarizedClips()
        }
    }

    /// Embed clips that haven't been processed yet.
    private func processUnembeddedClips() async {
        guard let clips = try? repository.unembeddedClips(limit: 20) else { return }
        guard !clips.isEmpty else { return }

        print("AIProcessor: Embedding \(clips.count) clips...")

        // Use batch embedding for efficiency
        let batch = clips.compactMap { clip -> (id: Int64, content: String)? in
            guard let id = clip.id else { return nil }
            return (id: id, content: clip.content)
        }

        let success = await llm.embedBatch(clips: batch)

        if success {
            for clip in clips {
                if let id = clip.id {
                    try? repository.markEmbedded(id: id)
                }
            }
            print("AIProcessor: Embedded \(clips.count) clips")
        }
    }

    /// Generate summaries for long clips that don't have one yet.
    private func processUnsummarizedClips() async {
        guard let clips = try? repository.unsummarizedClips(limit: 5) else { return }
        guard !clips.isEmpty else { return }

        print("AIProcessor: Summarizing \(clips.count) clips...")

        for clip in clips {
            guard let id = clip.id else { continue }

            if let summary = await llm.generateSummary(for: clip.content) {
                try? repository.updateSummary(id: id, summary: summary)
            }

            // Also auto-tag while we're at it
            if clip.aiTags == nil {
                let tags = await llm.autoTag(content: clip.content)
                if !tags.isEmpty {
                    try? repository.updateTags(id: id, tags: tags)
                }
            }

            // Small delay between API calls to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        }
    }
}
