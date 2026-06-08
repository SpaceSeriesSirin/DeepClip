import Foundation
import SwiftUI
import AppKit

extension Date {
    /// Compact relative formatting for list rows / status bar.
    var relativeDescription: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var shortTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: self)
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBlank: Bool {
        trimmed.isEmpty
    }

    /// Truncates to `length` characters appending an ellipsis when needed.
    func truncated(to length: Int) -> String {
        guard count > length else { return self }
        return String(prefix(length)) + "…"
    }
}

extension ByteCountFormatter {
    static func string(forBytes bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

extension Color {
    /// A stable accent color per content type for sidebar / badges.
    static func forContentType(_ type: ContentType) -> Color {
        switch type {
        case .text: return .secondary
        case .image: return .purple
        case .url: return .blue
        case .terminal: return .green
        case .code: return .orange
        }
    }
}

extension Collection {
    /// Returns the element at `index` if it is within bounds, otherwise `nil`.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// SwiftUI wrapper around `NSVisualEffectView` for native frosted-glass
/// backgrounds (used by the quick panel overlay).
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
