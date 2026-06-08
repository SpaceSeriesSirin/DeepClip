import Foundation

/// Extracts links, emails, dates, phone numbers and addresses from text and
/// turns them into actionable suggestions (SPEC Phase 3.5).
enum IntentRecognizer {

    static func analyze(_ text: String) -> [ActionSuggestion] {
        guard !text.isBlank else { return [] }
        var suggestions: [ActionSuggestion] = []
        var seen = Set<String>()

        func add(_ s: ActionSuggestion) {
            let key = "\(s.kind.rawValue):\(s.value)"
            guard !seen.contains(key) else { return }
            seen.insert(key)
            suggestions.append(s)
        }

        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)

        // Use NSDataDetector for links, dates, phone numbers, addresses.
        let types: NSTextCheckingResult.CheckingType = [.link, .date, .phoneNumber, .address]
        if let detector = try? NSDataDetector(types: types.rawValue) {
            detector.enumerateMatches(in: text, range: full) { match, _, _ in
                guard let match else { return }
                switch match.resultType {
                case .link:
                    if let url = match.url {
                        if url.scheme == "mailto" {
                            let email = url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
                            add(ActionSuggestion(kind: .email, label: "Compose Email",
                                                 value: email, systemImage: "envelope"))
                        } else if url.host?.contains("github.com") == true {
                            add(ActionSuggestion(kind: .openGitHub, label: "Open on GitHub",
                                                 value: url.absoluteString, systemImage: "chevron.left.forwardslash.chevron.right"))
                        } else {
                            add(ActionSuggestion(kind: .openURL, label: "Open in Browser",
                                                 value: url.absoluteString, systemImage: "safari"))
                        }
                    }
                case .date:
                    let value = ns.substring(with: match.range)
                    add(ActionSuggestion(kind: .date, label: "Create Calendar Event",
                                         value: value, systemImage: "calendar.badge.plus"))
                case .phoneNumber:
                    if let number = match.phoneNumber {
                        add(ActionSuggestion(kind: .phone, label: "Call Number",
                                             value: number, systemImage: "phone"))
                    }
                case .address:
                    let value = ns.substring(with: match.range)
                    add(ActionSuggestion(kind: .address, label: "Show on Map",
                                         value: value, systemImage: "map"))
                default:
                    break
                }
            }
        }

        // Plain emails not caught as mailto links.
        if let emailRegex = try? NSRegularExpression(
            pattern: #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            options: .caseInsensitive
        ) {
            emailRegex.enumerateMatches(in: text, range: full) { match, _, _ in
                guard let match else { return }
                let value = ns.substring(with: match.range)
                add(ActionSuggestion(kind: .email, label: "Compose Email",
                                     value: value, systemImage: "envelope"))
            }
        }

        return suggestions
    }
}
