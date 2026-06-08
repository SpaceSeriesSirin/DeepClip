import Foundation

/// High-level façade over the AI providers. AppState configures it from
/// settings and calls into it for embeddings, summaries, smart classification,
/// semantic search ranking and dedup decisions.
final class AIService {
    private var config: AIConfig

    init(config: AIConfig) {
        self.config = config
    }

    func update(config: AIConfig) {
        self.config = config
    }

    var isAvailable: Bool { config.isEnabled }

    private func makeProvider() -> AIProvider? {
        switch config.provider {
        case .none:
            return nil
        case .openai, .llamacpp:
            return OpenAICompatibleProvider(config: config)
        case .ollama:
            return OllamaProvider(config: config)
        }
    }

    // MARK: - Embeddings

    func embed(_ text: String) async throws -> [Double] {
        guard let provider = makeProvider() else { throw AIError.disabled }
        let trimmed = String(text.prefix(8000))
        return try await provider.embed(trimmed)
    }

    func testConnection() async throws -> String {
        guard let provider = makeProvider() else { throw AIError.disabled }
        return try await provider.testConnection()
    }

    // MARK: - Title & summary

    func generateTitleAndSummary(for text: String) async throws -> (title: String, summary: String) {
        guard let provider = makeProvider() else { throw AIError.disabled }
        let input = String(text.prefix(4000))
        let system = "You generate concise metadata for clipboard snippets. Always answer in the same language as the content."
        let user = """
        Produce a short title (max 8 words) and a one-sentence summary for the following content.
        Respond strictly as JSON: {"title": "...", "summary": "..."}.

        Content:
        \(input)
        """
        let response = try await provider.complete(system: system, user: user, maxTokens: 200)
        if let parsed = Self.parseTitleSummary(response) {
            return parsed
        }
        // Fallback: use the first line as the title.
        let firstLine = response.components(separatedBy: .newlines).first ?? response
        return (String(firstLine.prefix(80)), response)
    }

    private static func parseTitleSummary(_ response: String) -> (title: String, summary: String)? {
        // Extract the first {...} block in case the model adds prose.
        guard let start = response.firstIndex(of: "{"),
              let end = response.lastIndex(of: "}") else { return nil }
        let jsonString = String(response[start...end])
        guard let data = jsonString.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = obj["title"] as? String,
              let summary = obj["summary"] as? String else {
            return nil
        }
        return (title.trimmed, summary.trimmed)
    }

    // MARK: - Smart classification

    func classify(_ text: String) async throws -> ContentType {
        guard let provider = makeProvider() else { throw AIError.disabled }
        let input = String(text.prefix(2000))
        let system = "You are a precise text classifier."
        let user = """
        Classify the following clipboard content into exactly one of these categories:
        text, url, terminal, code.
        - "terminal": shell / command-line commands.
        - "code": source code in any programming language.
        - "url": a single web link.
        - "text": anything else.
        Respond with only the single category word.

        Content:
        \(input)
        """
        let response = try await provider.complete(system: system, user: user, maxTokens: 10)
        let word = response.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        for type in [ContentType.terminal, .code, .url, .text] where word.contains(type.rawValue) {
            return type
        }
        return .text
    }

    // MARK: - Semantic search

    /// Ranks `items` by cosine similarity to `query`'s embedding. Items without
    /// an embedding are dropped. Returns items sorted best-first along with score.
    func semanticRank(query: String, items: [ClipboardItem]) async throws -> [(item: ClipboardItem, score: Double)] {
        let queryVector = try await embed(query)
        var scored: [(ClipboardItem, Double)] = []
        for item in items {
            guard let vector = item.embeddingVector, !vector.isEmpty else { continue }
            let score = VectorMath.cosineSimilarity(queryVector, vector)
            scored.append((item, score))
        }
        scored.sort { $0.1 > $1.1 }
        return scored.map { (item: $0.0, score: $0.1) }
    }

    // MARK: - Dedup

    /// Decides whether `candidate` text duplicates an existing item, combining
    /// edit-distance similarity with embedding cosine similarity when available.
    func isDuplicate(
        candidate: String,
        candidateEmbedding: [Double]?,
        against existing: [ClipboardItem],
        threshold: Double
    ) -> ClipboardItem? {
        let candTrimmed = candidate.trimmed
        guard !candTrimmed.isEmpty else { return nil }

        for item in existing {
            guard let existingText = item.textContent?.trimmed, !existingText.isEmpty else { continue }

            // Exact match short-circuit.
            if existingText == candTrimmed {
                return item
            }

            let editSim = TextSimilarity.normalizedSimilarity(candTrimmed, existingText)
            var combined = editSim

            if let candEmb = candidateEmbedding,
               let existingEmb = item.embeddingVector,
               !existingEmb.isEmpty {
                let cosine = VectorMath.cosineSimilarity(candEmb, existingEmb)
                // Weight embeddings a bit higher than raw edit distance.
                combined = (editSim * 0.4) + (cosine * 0.6)
            }

            if combined >= threshold {
                return item
            }
        }
        return nil
    }
}
