import Foundation
import NaturalLanguage

/// Core AI Embedding and Similarity Engine
/// Provides fully local semantic vectors using Apple's NLEmbedding (128-dimensional).
final class EmbeddingService {

    /// Singleton instance.
    static let shared = EmbeddingService()

    /// The local pre-trained model for sentence embeddings.
    /// Loaded eagerly to avoid lazy loading lag on first search.
    private let localModel = NLEmbedding.sentenceEmbedding(for: .english)

    private init() {}

    // MARK: - Embedding

    /// Embed text locally using NLEmbedding.
    /// Available offline, runs entirely on-device (macOS 14+).
    func embedLocally(_ text: String) -> [Float]? {
        guard let model = localModel else { return nil }
        
        // Truncate text before embedding (NLEmbedding performs poorly on massive text blocks)
        let processedText = preprocessText(text)
        guard !processedText.isEmpty else { return nil }

        guard let vector = model.vector(for: processedText), !vector.isEmpty else { return nil }

        // NLEmbedding returns [Double], sqlite needs Float for compactness.
        return vector.map { Float($0) }
    }

    // MARK: - Semantic Search

    /// Find clips semantically similar to a query string.
    /// Falls back gracefully if no vectors are stored or query is empty.
    func findSimilar(to query: String, in clips: [ClipItem], threshold: Float = 0.45) -> [ClipItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        guard let queryVec = embedLocally(trimmedQuery) else { return [] }

        return clips
            .compactMap { clip -> (ClipItem, Float)? in
                guard let vec = clip.embeddingVector else { return nil }
                
                // Compare the query to the clip's vector
                let score = cosineSimilarity(queryVec, vec)
                
                // Only return if it meets the confidence threshold
                return score > threshold ? (clip, score) : nil
            }
            .sorted { $0.1 > $1.1 }  // Sort descending by score
            .map { $0.0 }            // Extract just the items
    }

    // MARK: - Math (Cosine Similarity)

    /// Calculate the cosine similarity between two vectors.
    /// Returns 1.0 for identical vectors, 0.0 for orthogonal, -1.0 for opposite.
    func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct: Float = 0
        var magA: Float = 0
        var magB: Float = 0
        
        // Iterate through dimensions (Accelerate framework omitted for build portability)
        for i in 0..<a.count {
            let valA = a[i]
            let valB = b[i]
            dotProduct += valA * valB
            magA += valA * valA
            magB += valB * valB
        }
        
        let valMagA = sqrt(magA)
        let valMagB = sqrt(magB)
        
        guard valMagA > 0, valMagB > 0 else { return 0 }
        return dotProduct / (valMagA * valMagB)
    }

    // MARK: - Vector Serialization

    /// Convert a Float array to raw bytes (BLOB) for SQLite storage.
    func vectorToData(_ vector: [Float]) -> Data {
        vector.withUnsafeBufferPointer { buffer in
            Data(buffer: buffer)
        }
    }

    /// Convert raw bytes (BLOB) back to a Float array.
    func dataToVector(_ data: Data) -> [Float] {
        data.withUnsafeBytes { buffer in
            Array(buffer.bindMemory(to: Float.self))
        }
    }

    // MARK: - Preprocessing

    /// Clean and truncate text before passing to the embedding model.
    private func preprocessText(_ text: String) -> String {
        // Limit to 512 chars as local models don't scale well to massive documents
        String(text.prefix(512)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
