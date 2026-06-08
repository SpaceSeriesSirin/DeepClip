import AppKit

/// Handles process-level concerns: hides the Dock icon (menu-bar-only app) and
/// boots the clipboard monitor as soon as the app finishes launching.
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon. (Complements LSUIElement in the
        // bundled Info.plist; also takes effect during `swift run`.)
        NSApp.setActivationPolicy(.accessory)

        // Boot services on the main actor.
        Task { @MainActor in
            AppState.shared.start()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }
}
