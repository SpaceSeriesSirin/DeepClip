import SwiftUI

/// Top search bar. Plain text search filters live; semantic search runs on
/// submit (⏎) because it needs a network round-trip to embed the query.
struct SearchBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $appState.searchText)
                .textFieldStyle(.plain)
                .focused($focused)
                .onSubmit { appState.runSearch() }
                // macOS 13: single-argument onChange closure only.
                .onChange(of: appState.searchText) { newValue in
                    if !settings.enableSemanticSearch {
                        appState.reload()
                    } else if newValue.isEmpty {
                        appState.reload()
                    }
                }

            if appState.isSemanticSearching {
                ProgressView().controlSize(.small)
            }

            if !appState.searchText.isEmpty {
                Button {
                    appState.searchText = ""
                    appState.reload()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }

            if settings.enableSemanticSearch && appState.aiService.isAvailable {
                Text("AI")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    .foregroundStyle(Color.accentColor)
                    .help("Semantic search enabled — press return to search")
            }
        }
        .padding(8)
        .background(.bar)
    }

    private var placeholder: String {
        if settings.enableSemanticSearch && appState.aiService.isAvailable {
            return "Semantic search (press return)…"
        }
        return "Search clipboard…"
    }
}
