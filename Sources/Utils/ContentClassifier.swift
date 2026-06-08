import Foundation

/// Rule-based content classifier used for the baseline (non-AI) categorization.
/// Order of precedence: URL → terminal → code → plain text.
enum ContentClassifier {

    static func classify(text: String) -> ContentType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        if URLHelper.isURL(trimmed) {
            return .url
        }
        if isTerminalCommand(trimmed) {
            return .terminal
        }
        if isCode(trimmed) {
            return .code
        }
        return .text
    }

    // MARK: - Terminal

    /// Common shell command leaders.
    private static let shellCommands: Set<String> = [
        "cd", "ls", "pwd", "git", "npm", "npx", "yarn", "pnpm", "brew", "sudo",
        "cat", "grep", "egrep", "rg", "find", "curl", "wget", "docker", "kubectl",
        "ssh", "scp", "mkdir", "rmdir", "rm", "cp", "mv", "touch", "echo", "export",
        "source", "chmod", "chown", "tar", "zip", "unzip", "ping", "make", "cmake",
        "swift", "python", "python3", "pip", "pip3", "node", "go", "cargo", "rustc",
        "apt", "apt-get", "yum", "dnf", "pacman", "systemctl", "service", "kill",
        "ps", "top", "htop", "df", "du", "awk", "sed", "tail", "head", "less", "more",
        "ln", "diff", "which", "whoami", "open", "code", "vim", "nano", "screen", "tmux"
    ]

    static func isTerminalCommand(_ text: String) -> Bool {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return false }

        // Explicit prompt markers.
        if first.hasPrefix("$ ") || first.hasPrefix("> ") || first.hasPrefix("% ")
            || first.hasPrefix("#!/") || first == "$" {
            return true
        }

        // Leading command token matches a known shell command.
        let firstToken = first.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
        let normalized = firstToken.hasPrefix("$") ? String(firstToken.dropFirst()) : firstToken
        if shellCommands.contains(normalized) {
            return true
        }

        // Environment assignment prefix: FOO=bar command
        if first.range(of: #"^[A-Z_][A-Z0-9_]*=\S+\s+\S+"#, options: .regularExpression) != nil {
            return true
        }

        // Strong shell operators combined with a known command anywhere.
        if (text.contains(" | ") || text.contains(" && ") || text.contains(" || "))
            && lines.contains(where: { line in
                let token = line.split(separator: " ").first.map(String.init) ?? ""
                return shellCommands.contains(token)
            }) {
            return true
        }
        return false
    }

    // MARK: - Code

    private static let codeKeywords: [String] = [
        "func ", "function ", "def ", "class ", "struct ", "enum ", "interface ",
        "public ", "private ", "protected ", "static ", "import ", "#include",
        "package ", "namespace ", "return ", "const ", "var ", "let ", "println",
        "console.log", "printf", "System.out", "=> ", "fn ", "impl ", "trait ",
        "async ", "await ", "yield ", "lambda ", "throw ", "try {", "catch ",
        "<?php", "<html", "</", "/>", "SELECT ", "INSERT INTO", "UPDATE ", "@interface"
    ]

    static func isCode(_ text: String) -> Bool {
        let lower = text.lowercased()
        var score = 0

        for keyword in codeKeywords where lower.contains(keyword.lowercased()) {
            score += 1
        }

        // Structural braces / semicolons.
        if text.contains("{") && text.contains("}") { score += 1 }
        let semicolonLines = text.components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasSuffix(";") }
        if semicolonLines.count >= 2 { score += 1 }

        // Indented multi-line blocks are a code smell (in a good way).
        let indented = text.components(separatedBy: .newlines)
            .filter { $0.hasPrefix("    ") || $0.hasPrefix("\t") }
        if indented.count >= 2 { score += 1 }

        // JSON-ish object/array.
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (t.hasPrefix("{") && t.hasSuffix("}")) || (t.hasPrefix("[") && t.hasSuffix("]")) {
            score += 1
        }

        return score >= 2
    }
}
