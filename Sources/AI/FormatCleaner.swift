import Foundation

/// Deterministic text tidy-up used by the "format cleaning" feature.
enum FormatCleaner {

    /// Generic cleanup: trims trailing whitespace, collapses runs of spaces,
    /// normalizes line endings and removes excessive blank lines.
    static func clean(_ input: String) -> String {
        // Normalize CRLF / CR to LF.
        var text = input.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")

        // Strip trailing whitespace per line, collapse intra-line space runs.
        let lines = text.components(separatedBy: "\n").map { line -> String in
            var l = line.replacingOccurrences(of: "\t", with: "    ")
            // Collapse 2+ spaces (not leading indentation) into one.
            l = l.replacingOccurrences(of: #"(?<=\S)  +"#, with: " ", options: .regularExpression)
            // Trailing whitespace.
            while l.hasSuffix(" ") { l.removeLast() }
            return l
        }

        // Collapse 3+ blank lines into a single blank line.
        var result: [String] = []
        var blankRun = 0
        for line in lines {
            if line.isEmpty {
                blankRun += 1
                if blankRun <= 1 { result.append(line) }
            } else {
                blankRun = 0
                result.append(line)
            }
        }

        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Re-indents code by converting tabs to a consistent space width and
    /// trimming trailing whitespace, without altering relative structure.
    static func cleanCode(_ input: String, indentWidth: Int = 4) -> String {
        let spaces = String(repeating: " ", count: indentWidth)
        var text = input.replacingOccurrences(of: "\r\n", with: "\n")
        text = text.replacingOccurrences(of: "\r", with: "\n")
        let lines = text.components(separatedBy: "\n").map { line -> String in
            var l = line.replacingOccurrences(of: "\t", with: spaces)
            while l.hasSuffix(" ") { l.removeLast() }
            return l
        }
        return lines.joined(separator: "\n")
    }
}
