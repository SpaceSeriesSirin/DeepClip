import Foundation

/// Helpers for (de)serializing embedding vectors and computing similarity.
///
/// Embeddings are persisted as the UTF-8 bytes of a JSON array of doubles.
enum VectorMath {

    static func encode(_ vector: [Double]) -> Data {
        (try? JSONEncoder().encode(vector)) ?? Data()
    }

    static func decode(_ data: Data) -> [Double]? {
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode([Double].self, from: data)
    }

    /// Cosine similarity in the range [-1, 1]. Returns 0 for mismatched or
    /// empty vectors so callers can treat it as "no signal".
    static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard !a.isEmpty, a.count == b.count else { return 0 }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (sqrt(normA) * sqrt(normB))
    }
}
