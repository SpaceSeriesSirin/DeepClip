import SwiftUI
import AppKit

/// Right column: full preview + metadata + AI info + actions for the selection.
struct ItemDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        if appState.selectedItemIDs.count > 1 {
            multiSelection(count: appState.selectedItemIDs.count)
                .frame(minWidth: 280)
        } else if let item = appState.selectedItem {
            detail(for: item)
                .frame(minWidth: 280)
        } else {
            EmptyPlaceholderView(
                title: "No Selection",
                message: "Select an item from the list to preview its content and metadata.",
                systemImage: "sidebar.squares.right"
            )
            .frame(minWidth: 280)
        }
    }

    // MARK: - Multi-selection summary

    private func multiSelection(count: Int) -> some View {
        let selected = appState.selectedItems
        let pinnedCount = selected.filter { $0.isPinned }.count
        let allPinned = pinnedCount == selected.count
        let copyableCount = selected.filter { $0.textContent != nil }.count

        return VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("\(count) items selected")
                    .font(.title2.weight(.semibold))
                Text("Apply an action to all selected items.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Button {
                    appState.copySelected()
                } label: {
                    Label("Copy \(copyableCount) item(s)", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .disabled(copyableCount == 0)

                Button {
                    appState.togglePinSelected()
                } label: {
                    Label(allPinned ? "Unpin All" : "Pin All",
                          systemImage: allPinned ? "pin.slash" : "pin")
                        .frame(maxWidth: .infinity)
                }

                Button(role: .destructive) {
                    appState.deleteSelected()
                } label: {
                    Label("Delete \(count) item(s)", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .frame(maxWidth: 280)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func detail(for item: ClipboardItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header(item)
                Divider()
                contentPreview(item)

                if let summary = item.summary, !summary.isBlank {
                    section("AI Summary", systemImage: "sparkles") {
                        Text(summary).textSelection(.enabled)
                    }
                }

                let suggestions = appState.suggestions(for: item)
                if !suggestions.isEmpty {
                    section("Suggested Actions", systemImage: "lightbulb") {
                        FlowActions(suggestions: suggestions)
                    }
                }

                if settings.enableSmartConvert, item.type != .image {
                    section("Convert", systemImage: "wand.and.stars") {
                        convertButtons(item)
                    }
                }

                metadata(item)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header

    private func header(_ item: ClipboardItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(item.type.displayName, systemImage: item.type.systemImage)
                    .font(.headline)
                    .foregroundStyle(Color.forContentType(item.type))
                Spacer()
                if appState.aiBusy {
                    ProgressView().controlSize(.small)
                }
            }

            if let title = item.title, !title.isBlank {
                Text(title).font(.title3.weight(.semibold)).textSelection(.enabled)
            }

            HStack(spacing: 12) {
                Button {
                    appState.copyToClipboard(item)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button {
                    appState.togglePin(item)
                } label: {
                    Label(item.isPinned ? "Unpin" : "Pin",
                          systemImage: item.isPinned ? "pin.slash" : "pin")
                }

                if item.type == .url, let text = item.textContent, let url = makeURL(text) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open", systemImage: "safari")
                    }
                }

                Spacer()

                Button(role: .destructive) {
                    appState.delete(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentPreview(_ item: ClipboardItem) -> some View {
        if item.type == .image, let data = item.imageData, let image = ImageHelper.image(from: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 360)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary)
                )
        } else if let text = item.textContent {
            ScrollView {
                Text(text)
                    .font(.system(.body, design: item.type == .code || item.type == .terminal ? .monospaced : .default))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            // Apply selection at the container level too; ScrollView can
            // otherwise intercept the drag gesture used for text selection.
            .textSelection(.enabled)
            .frame(maxHeight: 300)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary)
            )
        }
    }

    // MARK: - Convert

    private func convertButtons(_ item: ClipboardItem) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(SmartConvert.Operation.allCases) { op in
                Button(op.displayName) {
                    appState.applyConversion(op, to: item)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    // MARK: - Metadata

    private func metadata(_ item: ClipboardItem) -> some View {
        section("Details", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 6) {
                metaRow("Captured", item.capturedAt.shortTimestamp)
                if let expires = item.expiresAt {
                    metaRow("Expires", expires.shortTimestamp)
                } else {
                    metaRow("Expires", item.isPinned ? "Never (pinned)" : "Never")
                }
                if let app = item.sourceApp { metaRow("Source App", app) }
                if let domain = item.urlDomain { metaRow("Domain", domain) }
                if item.type == .image, let data = item.imageData {
                    metaRow("Size", ByteCountFormatter.string(forBytes: Int64(data.count)))
                    if let dims = ImageHelper.dimensions(of: data) {
                        metaRow("Dimensions", "\(dims.width) × \(dims.height)")
                    }
                } else if let text = item.textContent {
                    metaRow("Characters", "\(text.count)")
                }
                if let vector = item.embeddingVector {
                    metaRow("Embedding", "\(vector.count)-dim vector")
                }
            }
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)
            Text(value).textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    // MARK: - Helpers

    private func section<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func makeURL(_ text: String) -> URL? {
        var t = text.trimmed
        if !t.lowercased().hasPrefix("http") { t = "https://" + t }
        return URL(string: t)
    }
}

/// A wrapping row of action-suggestion buttons.
private struct FlowActions: View {
    let suggestions: [ActionSuggestion]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(suggestions) { suggestion in
                if let url = suggestion.actionURL {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("\(suggestion.label): \(suggestion.value.truncated(to: 24))",
                              systemImage: suggestion.systemImage)
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Label("\(suggestion.label): \(suggestion.value.truncated(to: 24))",
                          systemImage: suggestion.systemImage)
                        .lineLimit(1)
                        .font(.callout)
                        .padding(.vertical, 3)
                }
            }
        }
    }
}
