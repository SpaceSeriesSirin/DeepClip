import Foundation

/// Utilities for detecting and normalizing URLs and extracting domains.
enum URLHelper {

    /// Returns true when the entire (trimmed) string is a single web URL.
    static func isURL(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" "), !trimmed.contains("\n") else {
            return false
        }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: trimmed)?.host != nil
        }
        // Bare domains like "github.com/foo" or "x.com"
        if let match = bareDomainRegex.firstMatch(
            in: trimmed,
            range: NSRange(trimmed.startIndex..., in: trimmed)
        ), match.range.length == trimmed.utf16.count {
            return true
        }
        return false
    }

    /// Extracts the host/domain (without `www.`) from a URL-ish string.
    static func domain(from string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        var candidate = trimmed
        if !candidate.lowercased().hasPrefix("http://"),
           !candidate.lowercased().hasPrefix("https://") {
            candidate = "https://" + candidate
        }
        guard let host = URL(string: candidate)?.host else { return nil }
        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }
        return host
    }

    private static let bareDomainRegex: NSRegularExpression = {
        // host.tld optionally followed by a path. e.g. x.com, github.com/elon
        let pattern = #"^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(/\S*)?$"#
        return try! NSRegularExpression(pattern: pattern)
    }()
}
