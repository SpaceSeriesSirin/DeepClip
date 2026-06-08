import SwiftUI

/// Bottom status bar: item count, last update time, AI provider state, message.
struct StatusBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        HStack(spacing: 12) {
            Label("\(appState.totalCount)", systemImage: "number")
                .help("Total items")

            if appState.pinnedCount > 0 {
                Label("\(appState.pinnedCount)", systemImage: "pin.fill")
                    .help("Pinned items")
            }

            if appState.isMonitoringPaused {
                Divider().frame(height: 12)
                Button {
                    appState.resumeMonitoring()
                } label: {
                    Label("Paused", systemImage: "pause.circle.fill")
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Monitoring is paused — click to resume")
            }

            Divider().frame(height: 12)

            if !appState.statusMessage.isEmpty {
                Text(appState.statusMessage)
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if appState.aiBusy {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.small)
                    Text("AI…")
                }
                .foregroundStyle(.secondary)
            }

            if settings.aiProvider != .none {
                Label(settings.aiProvider.displayName, systemImage: "brain")
                    .foregroundStyle(.secondary)
                    .help("AI provider")
            }

            if let updated = appState.lastUpdated {
                Text("Updated \(updated.relativeDescription)")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.caption)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}
