import Foundation

/// Deterministic, local text transformations exposed via the "smart convert"
/// feature. None of these require a network/AI backend.
enum SmartConvert {

    enum Operation: String, CaseIterable, Identifiable {
        case markdownToPlain
        case plainToMarkdown
        case formatJSON
        case minifyJSON
        case urlDecode
        case urlEncode
        case base64Encode
        case base64Decode

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .markdownToPlain: return "Markdown → Plain Text"
            case .plainToMarkdown: return "Plain Text → Markdown"
            case .formatJSON: return "Format JSON"
            case .minifyJSON: return "Minify JSON"
            case .urlDecode: return "URL Decode"
            case .urlEncode: return "URL Encode"
            case .base64Encode: return "Base64 Encode"
            case .base64Decode: return "Base64 Decode"
            }
        }
    }

    static func apply(_ op: Operation, to input: String) -> String? {
        switch op {
        case .markdownToPlain: return markdownToPlain(input)
        case .plainToMarkdown: return plainToMarkdown(input)
        case .formatJSON: return formatJSON(input, pretty: true)
        case .minifyJSON: return formatJSON(input, pretty: false)
        case .urlDecode: return input.removingPercentEncoding
        case .urlEncode: return input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
        case .base64Encode: return input.data(using: .utf8)?.base64EncodedString()
        case .base64Decode:
            guard let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return nil
            }
            return String(data: data, encoding: .utf8)
        }
    }

    // MARK: - Markdown

    static func markdownToPlain(_ markdown: String) -> String {
        var text = markdown
        // Headers
        text = text.replacingOccurrences(of: #"(?m)^#{1,6}\s+"#, with: "", options: .regularExpression)
        // Bold / italic
        text = text.replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"__(.+?)__"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"_(.+?)_"#, with: "$1", options: .regularExpression)
        // Inline code & fences
        text = text.replacingOccurrences(of: #"`{1,3}"#, with: "", options: .regularExpression)
        // Links [text](url) -> text (url)
        text = text.replacingOccurrences(of: #"\[(.+?)\]\((.+?)\)"#, with: "$1 ($2)", options: .regularExpression)
        // List markers
        text = text.replacingOccurrences(of: #"(?m)^\s*[-*+]\s+"#, with: "• ", options: .regularExpression)
        // Blockquotes
        text = text.replacingOccurrences(of: #"(?m)^\s*>\s?"#, with: "", options: .regularExpression)
        return text
    }

    static func plainToMarkdown(_ text: String) -> String {
        // Escape characters that are meaningful in markdown.
        let specials = ["\\", "`", "*", "_", "{", "}", "[", "]", "(", ")", "#", "+", "-", "!"]
        var escaped = text
        for ch in specials {
            escaped = escaped.replacingOccurrences(of: ch, with: "\\" + ch)
        }
        return escaped
    }

    // MARK: - JSON

    static func formatJSON(_ input: String, pretty: Bool) -> String? {
        guard let data = input.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        var options: JSONSerialization.WritingOptions = [.fragmentsAllowed]
        if pretty {
            options.insert(.prettyPrinted)
            options.insert(.sortedKeys)
        }
        guard let out = try? JSONSerialization.data(withJSONObject: object, options: options) else {
            return nil
        }
        return String(data: out, encoding: .utf8)
    }
}
