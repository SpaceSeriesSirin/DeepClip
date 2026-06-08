import Foundation

/// Provider for any OpenAI-compatible HTTP API. Used for both the OpenAI cloud
/// service and a local `llama.cpp` server (which exposes `/v1/embeddings` and
/// `/v1/chat/completions`).
struct OpenAICompatibleProvider: AIProvider {
    let config: AIConfig

    private var headers: [String: String] {
        var h: [String: String] = [:]
        if !config.apiKey.isEmpty {
            h["Authorization"] = "Bearer \(config.apiKey)"
        }
        return h
    }

    func embed(_ text: String) async throws -> [Double] {
        let url = try AIHTTP.makeURL(base: config.endpoint, path: "/v1/embeddings")
        let body: [String: Any] = [
            "model": config.model,
            "input": text
        ]
        let data = try await AIHTTP.postJSON(url: url, body: body, headers: headers)
        return try Self.parseEmbedding(data)
    }

    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        let url = try AIHTTP.makeURL(base: config.endpoint, path: "/v1/chat/completions")
        let body: [String: Any] = [
            "model": config.model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.2,
            "max_tokens": maxTokens
        ]
        let data = try await AIHTTP.postJSON(url: url, body: body, headers: headers)
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let content = message["content"] as? String
        else {
            throw AIError.decodingFailed
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.emptyResponse }
        return trimmed
    }

    func testConnection() async throws -> String {
        let vector = try await embed("ping")
        return "OK — embedding dimension \(vector.count)"
    }

    static func parseEmbedding(_ data: Data) throws -> [Double] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIError.decodingFailed
        }
        // OpenAI shape: { "data": [ { "embedding": [..] } ] }
        if let dataArr = json["data"] as? [[String: Any]],
           let first = dataArr.first,
           let embedding = first["embedding"] as? [Any] {
            return embedding.compactMap { ($0 as? NSNumber)?.doubleValue }
        }
        // Some servers return { "embedding": [..] } directly.
        if let embedding = json["embedding"] as? [Any] {
            return embedding.compactMap { ($0 as? NSNumber)?.doubleValue }
        }
        throw AIError.decodingFailed
    }
}
