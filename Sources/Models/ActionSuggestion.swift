import Foundation

/// A suggested action derived from intent recognition over an item's content.
struct ActionSuggestion: Identifiable, Hashable {
    enum Kind: String {
        case openURL
        case openGitHub
        case email
        case date
        case phone
        case address
    }

    let id = UUID()
    let kind: Kind
    /// User-facing button label, e.g. "Open in Browser".
    let label: String
    /// The extracted raw value (URL, email, date string, …).
    let value: String
    let systemImage: String

    /// A URL the UI can open for this suggestion, when applicable.
    var actionURL: URL? {
        switch kind {
        case .openURL, .openGitHub:
            var v = value
            if !v.lowercased().hasPrefix("http") { v = "https://" + v }
            return URL(string: v)
        case .email:
            return URL(string: "mailto:\(value)")
        case .phone:
            let digits = value.filter { $0.isNumber || $0 == "+" }
            return URL(string: "tel:\(digits)")
        case .date, .address:
            return nil
        }
    }
}
