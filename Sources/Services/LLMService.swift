import Foundation

/// Full interface to the `llm` CLI tool for AI-powered features.
/// Shells out to `llm` for prompts, embeddings, and similarity search.
final class LLMService {
    /// Singleton instance.
    static let shared = LLMService()

    /// Whether the `llm` CLI tool is installed and accessible.
    private(set) var isInstalled: Bool = false

    /// Resolved path to the `llm` binary.
    private var llmPath: String?

    /// The default embedding model (user can configure via `llm embed-models default`).
    private(set) var embeddingModel: String?

    /// Name of the embedding collection used by ClipStash.
    static let collectionName = "clipstash"

    /// Custom database path for embeddings (stored alongside clip history).
    private var embeddingsDBPath: String {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("ClipStash", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("embeddings.db").path
    }

    private init() {
        checkInstallation()
    }

    // MARK: - Installation Check

    /// Check if `llm` is available on the system PATH.
    func checkInstallation() {
        do {
            let path = try runProcess("/usr/bin/env", arguments: ["which", "llm"])
            let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                isInstalled = true
                llmPath = trimmed
                print("LLMService: Found llm at \(trimmed)")

                // Check for default embedding model
                if let models = try? runProcess("/usr/bin/env", arguments: ["llm", "embed-models", "default"]) {
                    let model = models.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !model.isEmpty && !model.contains("Error") && !model.contains("Usage") {
                        embeddingModel = model
                        print("LLMService: Default embedding model: \(model)")
                    }
                }
            }
        } catch {
            isInstalled = false
            print("LLMService: llm not found — \(error)")
        }
    }

    // MARK: - Prompts (Summaries, Tagging)

    /// Generate a one-line summary of the given text.
    func generateSummary(for text: String) async -> String? {
        guard isInstalled else { return nil }
        // Skip short content — no point summarizing a single line
        guard text.count > 200 else { return nil }

        let prompt = "Summarize the following in one short sentence (max 15 words). Return ONLY the summary, no quotes, no preamble:\n\n\(text.prefix(2000))"

        do {
            let result = try await runLLMAsync(arguments: ["prompt", prompt])
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return trimmed
        } catch {
            print("LLMService: summary error — \(error)")
            return nil
        }
    }

    /// Auto-tag clip content using AI classification.
    func autoTag(content: String) async -> [String] {
        guard isInstalled else { return [] }

        let prompt = """
        Classify the following text into 1-3 tags from this list ONLY: \
        code, url, email, address, phone, password, api-key, sql, json, \
        markdown, terminal-command, error-message, log, config, snippet, note.
        Return ONLY comma-separated tags, nothing else.

        Text: \(content.prefix(1000))
        """

        do {
            let result = try await runLLMAsync(arguments: ["prompt", prompt])
            let tags = result
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return tags
        } catch {
            print("LLMService: autoTag error — \(error)")
            return []
        }
    }

    // MARK: - Embeddings

    /// Embed a single clip and store it in the ClipStash collection.
    /// Uses the clip's DB id as the embedding key.
    func embedClip(id: Int64, content: String) async -> Bool {
        guard isInstalled else { return false }

        // Truncate content for embedding (most models have token limits)
        let truncated = String(content.prefix(8000))

        do {
            _ = try await runLLMAsync(arguments: [
                "embed", Self.collectionName, String(id),
                "-d", embeddingsDBPath,
                "-c", truncated,
                "--store",
            ])
            return true
        } catch {
            print("LLMService: embed error for clip \(id) — \(error)")
            return false
        }
    }

    /// Semantic search: find clips similar to a natural language query.
    /// Returns array of (clipID, score) tuples, sorted by relevance.
    func semanticSearch(query: String, limit: Int = 20) async -> [(id: String, score: Double)] {
        guard isInstalled else { return [] }

        do {
            let result = try await runLLMAsync(arguments: [
                "similar", Self.collectionName,
                "-d", embeddingsDBPath,
                "-c", query,
                "-n", String(limit),
            ])

            // Parse NDJSON output: each line is {"id": "123", "score": 0.85, ...}
            return parseNDJSON(result)
        } catch {
            print("LLMService: semantic search error — \(error)")
            return []
        }
    }

    /// Batch embed multiple clips at once using NDJSON piped to embed-multi.
    func embedBatch(clips: [(id: Int64, content: String)]) async -> Bool {
        guard isInstalled, !clips.isEmpty else { return false }

        // Build NDJSON input
        let inputData: String = clips.map { clip in
            let escaped = clip.content.prefix(8000)
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "{\"id\": \"\(clip.id)\", \"content\": \"\(escaped)\"}"
        }.joined(separator: "\n")

        do {
            try await runLLMAsyncWithStdin(
                arguments: [
                    "embed-multi", Self.collectionName,
                    "-d", embeddingsDBPath,
                    "-", "--format", "nl",
                    "--store",
                ],
                stdin: inputData
            )
            return true
        } catch {
            print("LLMService: batch embed error — \(error)")
            return false
        }
    }

    /// Check how many clips have been embedded.
    func embeddedCount() -> Int {
        guard isInstalled else { return 0 }
        do {
            let result = try runProcess("/usr/bin/env", arguments: [
                "llm", "collections", "list", "-d", embeddingsDBPath,
            ])
            // Parse collection list to find our collection's count
            if result.contains(Self.collectionName) {
                return -1  // Collection exists but we can't easily get count from CLI
            }
            return 0
        } catch {
            return 0
        }
    }

    // MARK: - Process Helpers

    /// Run a process synchronously and return stdout.
    private func runProcess(_ executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        // Inherit user's PATH so llm is findable
        var env = ProcessInfo.processInfo.environment
        // Add common brew/pip paths
        let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "\(NSHomeDirectory())/.local/bin"]
        let currentPath = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errStr = String(data: errData, encoding: .utf8) ?? ""
            throw LLMError.processError(status: process.terminationStatus, stderr: errStr)
        }

        return output
    }

    /// Run an `llm` CLI command asynchronously.
    private func runLLMAsync(arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.runProcess("/usr/bin/env", arguments: ["llm"] + arguments)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Run an `llm` CLI command with stdin data.
    private func runLLMAsyncWithStdin(arguments: [String], stdin: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                process.arguments = ["llm"] + arguments

                var env = ProcessInfo.processInfo.environment
                let extraPaths = ["/opt/homebrew/bin", "/usr/local/bin", "\(NSHomeDirectory())/.local/bin"]
                let currentPath = env["PATH"] ?? "/usr/bin:/bin"
                env["PATH"] = (extraPaths + [currentPath]).joined(separator: ":")
                process.environment = env

                let stdinPipe = Pipe()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardInput = stdinPipe
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                    // Write stdin data
                    stdinPipe.fileHandleForWriting.write(Data(stdin.utf8))
                    stdinPipe.fileHandleForWriting.closeFile()
                    process.waitUntilExit()

                    if process.terminationStatus != 0 {
                        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                        let errStr = String(data: errData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: LLMError.processError(status: process.terminationStatus, stderr: errStr))
                    } else {
                        continuation.resume(returning: ())
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Parse NDJSON output from `llm similar`.
    private func parseNDJSON(_ output: String) -> [(id: String, score: Double)] {
        let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return lines.compactMap { line in
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let id = json["id"] as? String,
                  let score = json["score"] as? Double else {
                return nil
            }
            return (id: id, score: score)
        }
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case processError(status: Int32, stderr: String)
    case notInstalled

    var errorDescription: String? {
        switch self {
        case .processError(let status, let stderr):
            return "llm exited with status \(status): \(stderr)"
        case .notInstalled:
            return "llm CLI is not installed"
        }
    }
}
