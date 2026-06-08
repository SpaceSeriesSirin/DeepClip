import Foundation

/// Which backend powers the AI features.
enum AIProviderType: String, CaseIterable, Identifiable, Codable {
    case none
    case openai
    case llamacpp
    case ollama

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "Disabled"
        case .openai: return "OpenAI (Cloud)"
        case .llamacpp: return "llama.cpp Server"
        case .ollama: return "Ollama"
        }
    }

    /// A reasonable default endpoint for each provider.
    var defaultEndpoint: String {
        switch self {
        case .none: return ""
        case .openai: return "https://api.openai.com"
        case .llamacpp: return "http://localhost:8080"
        case .ollama: return "http://localhost:11434"
        }
    }

    /// Whether the provider requires an API key.
    var requiresAPIKey: Bool {
        self == .openai
    }
}

/// Snapshot of the AI configuration, derived from settings.
struct AIConfig: Equatable {
    var provider: AIProviderType
    var endpoint: String
    var model: String
    var apiKey: String

    var isEnabled: Bool { provider != .none }
}

/// Errors surfaced by AI providers.
enum AIError: LocalizedError {
    case disabled
    case invalidEndpoint
    case requestFailed(Int, String)
    case decodingFailed
    case emptyResponse
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .disabled: return "AI provider is disabled."
        case .invalidEndpoint: return "The configured AI endpoint is invalid."
        case .requestFailed(let code, let body):
            return "AI request failed (HTTP \(code)): \(body)"
        case .decodingFailed: return "Could not decode the AI response."
        case .emptyResponse: return "The AI provider returned an empty response."
        case .transport(let message): return "Network error: \(message)"
        }
    }
}
