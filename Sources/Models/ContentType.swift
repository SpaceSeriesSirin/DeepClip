import Foundation

/// The category a clipboard item belongs to. Drives sidebar grouping and icons.
enum ContentType: String, Codable, CaseIterable, Identifiable {
    case text
    case image
    case url
    case terminal
    case code

    var id: String { rawValue }

    /// Human friendly localized-ish display name used in the sidebar / detail.
    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .url: return "URL"
        case .terminal: return "Terminal"
        case .code: return "Code"
        }
    }

    /// SF Symbol used to represent the type in the UI.
    var systemImage: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .url: return "link"
        case .terminal: return "terminal"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }
}
