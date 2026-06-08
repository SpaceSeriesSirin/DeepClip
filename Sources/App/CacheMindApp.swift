import SwiftUI

extension Notification.Name {
    /// Posted by the global hotkey handler when no main window exists yet and one
    /// must be opened via SwiftUI's `openWindow` environment action.
    static let summonMainWindow = Notification.Name("summonMainWindow")
}

@main
struct CacheMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Full main window (sidebar + list + preview + search + status bar).
        Window("CacheMind", id: WindowID.main) {
            MainView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .frame(minWidth: 760, minHeight: 460)
        }
        .defaultSize(width: 980, height: 600)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            ClipboardCommands(appState: appState)
        }

        // Settings window (opened from the menu-bar popover or ⌘,).
        Window("Settings", id: WindowID.settings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .frame(width: 560, height: 520)
        }
        .windowResizability(.contentSize)

        // Always-present menu-bar item with a popover UI. Its content view is
        // always alive, so it also hosts the hotkey "summon main window" handler.
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(appState)
                .environmentObject(appState.settings)
                .onReceive(NotificationCenter.default.publisher(for: .summonMainWindow)) { _ in
                    openWindow(id: WindowID.main)
                    NSApp.activate(ignoringOtherApps: true)
                }
        } label: {
            // Icon reflects monitoring state: a filled clipboard with a pause
            // tint when paused, the outline clipboard while active.
            Image(systemName: appState.isMonitoringPaused
                  ? "pause.circle.fill"
                  : "doc.on.clipboard")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Stable identifiers for the app's windows.
enum WindowID {
    static let main = "main"
    static let settings = "settings"
}

/// App menu commands (Edit-style shortcuts for the focused main window).
struct ClipboardCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Selected Item") {
                if let item = appState.selectedItem {
                    appState.copyToClipboard(item)
                }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(appState.selectedItem == nil)

            Button(appState.selectedItem?.isPinned == true ? "Unpin Selected" : "Pin Selected") {
                if let item = appState.selectedItem {
                    appState.togglePin(item)
                }
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(appState.selectedItem == nil)

            Button("Delete Selected Item") {
                appState.deleteSelected()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(appState.selectedItem == nil)
        }
    }
}
