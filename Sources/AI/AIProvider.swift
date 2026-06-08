import Foundation
import os

/// Unified interface for embedding + chat backends.
protocol AIProvider {
    /// Generate an embedding vector for a piece of text.
    func embed(_ text: String) async throws -> [Double]

    /// A free-form chat/instruction completion (used for summaries, smart
    /// classification, etc). Implementations may throw `.disabled` if the
    /// backend does not support chat.
    func complete(system: String, user: String, maxTokens: Int) async throws -> String

    /// Lightweight connectivity check used by the settings "Test" button.
    func testConnection() async throws -> String
}

/// Shared HTTP helpers for the concrete providers.
enum AIHTTP {
    static func makeURL(base: String, path: String) throws -> URL {
        // Aggressively sanitize: strip whitespace, newlines, and all control /
        // invisible Unicode characters that can sneak in from copy-paste.
        var trimmed = base.unicodeScalars.filter { scalar in
            !CharacterSet.whitespacesAndNewlines.contains(scalar)
                && !CharacterSet.controlCharacters.contains(scalar)
                && !CharacterSet.illegalCharacters.contains(scalar)
                && scalar != "\u{200B}" // zero-width space
                && scalar != "\u{FEFF}" // zero-width no-break space / BOM
        }
        .map(Character.init)
        .reduce(into: "") { $0.append($1) }

        // Auto-prepend a scheme if the user typed a bare host:port like
        // "127.0.0.1:8080" with no "http://" / "https://" prefix.
        if !trimmed.isEmpty,
           trimmed.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) == nil {
            trimmed = "http://" + trimmed
        }

        while trimmed.hasSuffix("/") { trimmed.removeLast() }

        let candidate = trimmed + path

        // First attempt: direct construction.
        if let url = URL(string: candidate), url.host != nil {
            return url
        }

        // Second attempt: percent-encode the candidate in case stray characters
        // (e.g. in the host) prevented `URL(string:)` from parsing.
        if let encoded = candidate.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded), url.host != nil {
            return url
        }

        AppLogger.ai.error(
            "makeURL failed to build a valid endpoint URL. base=\(base, privacy: .public) sanitized=\(candidate, privacy: .public)"
        )
        throw AIError.invalidEndpoint
    }

    static func postJSON(
        url: URL,
        body: [String: Any],
        headers: [String: String] = [:],
        timeout: TimeInterval = 30
    ) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers {
            request.setValue(v, forHTTPHeaderField: k)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw AIError.transport("No HTTP response")
            }
            guard (200..<300).contains(http.statusCode) else {
                let bodyText = String(data: data, encoding: .utf8) ?? ""
                throw AIError.requestFailed(http.statusCode, String(bodyText.prefix(500)))
            }
            return data
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.transport(error.localizedDescription)
        }
    }
}
