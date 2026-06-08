import Foundation
import AppKit

/// Writes content back to the system pasteboard (manual re-copy).
@MainActor
enum PasteboardWriter {

    static func copy(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .image:
            if let data = item.imageData {
                pasteboard.setData(data, forType: .png)
            }
        case .url:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
                pasteboard.setString(text, forType: .URL)
            }
        default:
            if let text = item.textContent {
                pasteboard.setString(text, forType: .string)
            }
        }
    }

    static func copyText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
