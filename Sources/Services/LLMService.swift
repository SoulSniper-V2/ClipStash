import Foundation

/// Interface to the `llm` CLI tool for AI-powered features.
/// Stub implementation for V2 — all methods are non-functional placeholders.
final class LLMService {
    /// Singleton instance.
    static let shared = LLMService()

    /// Whether the `llm` CLI tool is installed and accessible.
    private(set) var isInstalled: Bool = false

    /// The currently configured model (e.g. "gpt-4o-mini", "claude-3-haiku").
    private(set) var currentModel: String?

    private init() {
        checkInstallation()
    }

    // MARK: - Installation Check

    /// Check if `llm` is available on the system PATH.
    func checkInstallation() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", "llm"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            isInstalled = process.terminationStatus == 0

            if isInstalled {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                print("LLMService: Found llm at \(path ?? "unknown")")
            }
        } catch {
            isInstalled = false
            print("LLMService: llm not found — \(error)")
        }
    }

    // MARK: - V2 Stubs

    /// Generate a one-line summary of the given text.
    /// - Returns: Summary string, or nil if llm is not available.
    func generateSummary(for text: String) async -> String? {
        guard isInstalled else { return nil }
        // V2: Shell out to `llm -m <model> "Summarize in one sentence: <text>"`
        return nil
    }

    /// Generate an embedding vector for the given text.
    /// - Returns: Array of floats, or nil if not available.
    func embed(text: String) async -> [Float]? {
        guard isInstalled else { return nil }
        // V2: Shell out to `llm embed -m <model> -c "<text>"`
        return nil
    }

    /// Semantic search: find clips matching a natural language query.
    /// - Returns: Array of matching clip IDs ranked by relevance.
    func semanticSearch(query: String, clips: [ClipItem]) async -> [Int64] {
        guard isInstalled else { return [] }
        // V2: Embed query, compare against stored embeddings
        return []
    }

    /// Auto-tag a clip's content type using AI.
    /// - Returns: Array of tag strings.
    func autoTag(content: String) async -> [String] {
        guard isInstalled else { return [] }
        // V2: Shell out to llm for classification
        return []
    }

    // MARK: - Helpers

    /// Run an `llm` CLI command and return stdout.
    private func runLLM(arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["llm"] + arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
