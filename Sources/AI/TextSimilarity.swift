import Foundation

/// Lightweight string-similarity helpers used by the smart-dedup feature.
enum TextSimilarity {

    /// Classic Levenshtein edit distance.
    static func levenshtein(_ a: String, _ b: String) -> Int {
        let s = Array(a)
        let t = Array(b)
        if s.isEmpty { return t.count }
        if t.isEmpty { return s.count }

        var previous = Array(0...t.count)
        var current = [Int](repeating: 0, count: t.count + 1)

        for i in 1...s.count {
            current[0] = i
            for j in 1...t.count {
                let cost = s[i - 1] == t[j - 1] ? 0 : 1
                current[j] = Swift.min(
                    previous[j] + 1,        // deletion
                    current[j - 1] + 1,     // insertion
                    previous[j - 1] + cost  // substitution
                )
            }
            swap(&previous, &current)
        }
        return previous[t.count]
    }

    /// Normalized similarity in [0, 1] derived from edit distance.
    static func normalizedSimilarity(_ a: String, _ b: String) -> Double {
        if a.isEmpty && b.isEmpty { return 1 }
        let distance = Double(levenshtein(a, b))
        let maxLen = Double(Swift.max(a.count, b.count))
        guard maxLen > 0 else { return 1 }
        return 1 - (distance / maxLen)
    }
}
