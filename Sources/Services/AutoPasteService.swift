import AppKit
import ApplicationServices

/// Simulates a paste keystroke into the previously-active application so that a
/// selected clipboard item lands directly where the user was typing, rather than
/// just sitting on the pasteboard.
///
/// Requires Accessibility permission (System Settings → Privacy & Security →
/// Accessibility) to post synthetic keyboard events via `CGEvent`.
enum AutoPasteService {

    /// `kVK_ANSI_V` — the virtual key code for the "V" key.
    private static let vKeyCode: CGKeyCode = 0x09

    /// Returns true if Accessibility permission is granted.
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user for Accessibility permission (shows the system dialog the
    /// first time and links to the relevant settings pane thereafter).
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    /// Simulate ⌘V in the previous app using `CGEvent`.
    static func pasteIntoPreviousApp(previousApp: NSRunningApplication?) {
        postPaste(into: previousApp, flags: .maskCommand)
    }

    /// Plain-text paste (⌥⇧⌘V — "Paste and Match Style" on macOS).
    static func pastePlainText(previousApp: NSRunningApplication?) {
        postPaste(into: previousApp, flags: [.maskCommand, .maskAlternate, .maskShift])
    }

    // MARK: - Private

    private static func postPaste(into previousApp: NSRunningApplication?, flags: CGEventFlags) {
        guard let app = previousApp, !app.isTerminated else { return }
        app.activate(options: .activateIgnoringOtherApps)
        Thread.sleep(forTimeInterval: 0.05)

        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = flags
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
