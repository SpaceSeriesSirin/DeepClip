import SwiftUI

/// Center column: the filtered, sorted list of clipboard items.
struct ItemListView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Group {
            if appState.items.isEmpty {
                EmptyPlaceholderView(
                    title: emptyTitle,
                    message: emptyMessage,
                    systemImage: "tray"
                )
            } else {
                List(selection: $appState.selectedItemIDs) {
                    ForEach(appState.items) { item in
                        ItemRowView(item: item)
                            .tag(item.id)
                            .onDrag { item.dragProvider() }
                            .contextMenu { contextMenu(for: item) }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 280)
        .navigationTitle(appState.selection.title)
        .onDeleteCommand { appState.deleteSelected() }
        .toolbar {
            ToolbarItemGroup {
                if appState.aiBusy {
                    ProgressView().controlSize(.small)
                        .help("AI processing…")
                }
                if !appState.items.isEmpty {
                    Button {
                        appState.selectAll()
                    } label: {
                        Label("Select All", systemImage: "checklist")
                    }
                    .keyboardShortcut("a", modifiers: .command)
                    .help("Select all items (⌘A)")
                }
                sortMenu
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $appState.sortOrder) {
                ForEach(ItemSortOrder.allCases) { order in
                    Text(order.displayName).tag(order)
                }
            }
            .pickerStyle(.inline)
            .onChange(of: appState.sortOrder) { _ in
                appState.reload()
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
        .help("Change sort order")
    }

    @ViewBuilder
    private func contextMenu(for item: ClipboardItem) -> some View {
        Button {
            appState.copyToClipboard(item)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }

        Button {
            appState.togglePin(item)
        } label: {
            Label(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin")
        }

        if settings.enableSmartConvert, item.type != .image {
            Menu {
                ForEach(SmartConvert.Operation.allCases) { op in
                    Button(op.displayName) {
                        appState.applyConversion(op, to: item)
                    }
                }
            } label: {
                Label("Convert", systemImage: "wand.and.stars")
            }
        }

        Divider()

        Button(role: .destructive) {
            appState.delete(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private var emptyTitle: String {
        appState.searchText.isEmpty ? "No Items" : "No Matches"
    }

    private var emptyMessage: String {
        if !appState.searchText.isEmpty {
            return "No clipboard items match your search."
        }
        switch appState.selection {
        case .all:
            return "Copy something and it will appear here automatically."
        case .pinned:
            return "Pin important items to keep them here permanently."
        default:
            return "Nothing in this category yet."
        }
    }
}
