import Foundation

/// Generative layer for text summarization and smart tagging.
/// Calls OpenAI `gpt-4o-mini` API directly when a user provides an API key.
final class SummaryService {

    static let shared = SummaryService()

    enum Provider: String {
        case openAI = "OpenAI"
        case anthropic = "Anthropic"
    }

    private init() {}

    // MARK: - Conditionals

    /// Determines if a clip is worth summarizing based on length and relevance.
    func shouldSummarize(_ text: String) -> Bool {
        // Clips shorter than 200 chars don't need a summary
        text.count > 200
    }

    /// Determines if a clip is worth tagging based on length and relevance.
    func shouldTag(_ text: String) -> Bool {
        // Shorter thresholds for tags (even short bash commands are worth tagging)
        text.count > 50
    }

    // MARK: - Summarization

    /// Ask the API for a quick, one-line summary.
    func summarize(_ text: String, provider: Provider, apiKey: String) async throws -> String {
        // Build generic URL/payload
        guard provider == .openAI else {
            // Anthropic is a placeholder for future implementations
            throw SummaryError.unsupportedProvider
        }

        let model = "gpt-4o-mini"
        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

        // Limit the prompt context out of scope bounds (8k tokens limit is generous, but just string truncation is faster)
        let processedText = String(text.prefix(4000))
        let maxOutputWords = 15

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a concise summarizer. Generate a one-line summary of the user's text. Return ONLY the summary text, no quotes, no bolding, no prefixes.",
                ],
                [
                    "role": "user",
                    "content": "Summarize this in one short sentence (max \(maxOutputWords) words): \(processedText)",
                ]
            ],
            "temperature": 0.0, // High determinism
            "max_completion_tokens": 40
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse else {
            throw SummaryError.invalidResponse
        }

        guard httpStatus.statusCode == 200 else {
            throw SummaryError.apiError(statusCode: httpStatus.statusCode, data: data)
        }

        guard let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResult["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw SummaryError.invalidResponse
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed
    }

    // MARK: - Auto-Tagging

    /// Classify a clip using AI tags from a predefined set.
    func tag(_ text: String, provider: Provider, apiKey: String) async throws -> [String] {
        guard provider == .openAI else {
            throw SummaryError.unsupportedProvider
        }

        let model = "gpt-4o-mini"
        let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
        let processedText = String(text.prefix(4000))
        let allowedTags = ["code", "sql", "url", "email", "address", "json", "key", "command", "error", "phone", "date", "note"]

        let body: [String: Any] = [
            "model": model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a classification engine. You must select 1-3 highly relevant tags for the provided text from the following exact list ONLY: \(allowedTags.joined(separator: ", ")). Output them as a strictly valid JSON array of strings, e.g. [\"code\", \"json\"]. Nothing else.",
                ],
                [
                    "role": "user",
                    "content": processedText
                ]
            ],
            "temperature": 0.0,
            "response_format": [ "type": "json_object" ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 else {
            throw SummaryError.apiError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, data: data)
        }

        guard let jsonResult = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonResult["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw SummaryError.invalidResponse
        }

        // Parse JSON array {"tags":["code"]} or direct array parsing based on JSON object wrapping
        let contentData = content.data(using: .utf8)!
        let parsed = try? JSONSerialization.jsonObject(with: contentData) as? [String: Any]
        
        // Find an array of strings in the returned JSON object regardless of key
        var extractedTags = [String]()
        if let dict = parsed {
            for (_, value) in dict {
                if let array = value as? [String] {
                    extractedTags = array
                    break
                }
            }
        }

        return extractedTags.filter { allowedTags.contains($0) }.prefix(3).map { $0 }
    }

    // MARK: - Error

    enum SummaryError: LocalizedError {
        case unsupportedProvider
        case invalidResponse
        case apiError(statusCode: Int, data: Data)

        var errorDescription: String? {
            switch self {
            case .unsupportedProvider:
                return "The selected provider is currently unsupported."
            case .invalidResponse:
                return "Failed to parse API response."
            case .apiError(let statusCode, let data):
                let body = String(data: data, encoding: .utf8) ?? "unknown"
                return "API failed with HTTP \(statusCode): \(body)"
            }
        }
    }
}
