import Foundation

/// Provider for a local Ollama server (default http://localhost:11434).
struct OllamaProvider: AIProvider {
    let config: AIConfig

    func embed(_ text: String) async throws -> [Double] {
        let url = try AIHTTP.makeURL(base: config.endpoint, path: "/api/embeddings")
        let body: [String: Any] = [
            "model": config.model,
            "prompt": text
        ]
        let data = try await AIHTTP.postJSON(url: url, body: body)
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let embedding = json["embedding"] as? [Any]
        else {
            throw AIError.decodingFailed
        }
        return embedding.compactMap { ($0 as? NSNumber)?.doubleValue }
    }

    func complete(system: String, user: String, maxTokens: Int) async throws -> String {
        let url = try AIHTTP.makeURL(base: config.endpoint, path: "/api/chat")
        let body: [String: Any] = [
            "model": config.model,
            "stream": false,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ]
        ]
        let data = try await AIHTTP.postJSON(url: url, body: body)
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["message"] as? [String: Any],
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
}
