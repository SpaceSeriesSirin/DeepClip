import SwiftUI

/// The main window: search bar on top, a three-column split (sidebar / list /
/// detail) in the middle, and the status bar pinned to the bottom.
struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView()
            Divider()

            NavigationSplitView {
                SidebarView()
            } content: {
                ItemListView()
            } detail: {
                ItemDetailView()
            }
            .navigationSplitViewStyle(.balanced)

            Divider()
            StatusBarView()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(id: WindowID.settings)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Open Settings")
            }
        }
    }
}
