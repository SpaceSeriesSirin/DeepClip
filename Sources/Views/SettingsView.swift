import SwiftUI

/// Settings window with General / AI / Data tabs (SPEC Phase 4.3).
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gearshape") }
            AISettingsView()
                .tabItem { Label("AI", systemImage: "brain") }
            DataSettingsView()
                .tabItem { Label("Data", systemImage: "externaldrive") }
        }
        .frame(width: 560, height: 520)
    }
}
