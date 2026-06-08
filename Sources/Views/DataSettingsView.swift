import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct DataSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var importMode: ImportMode = .merge
    @State private var showClearConfirm = false

    var body: some View {
        Form {
            Section("Database") {
                HStack {
                    Text("Items stored")
                    Spacer()
                    Text("\(appState.totalCount)").foregroundStyle(.secondary).monospacedDigit()
                }
                HStack {
                    Text("Database size")
                    Spacer()
                    Text(ByteCountFormatter.string(forBytes: appState.appDatabase.fileSize()))
                        .foregroundStyle(.secondary)
                }
            }

            Section("Export") {
                Text("Export all items and settings to a JSON file. Images are embedded as Base64.")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    exportAction()
                } label: {
                    Label("Export to JSON…", systemImage: "square.and.arrow.up")
                }
            }

            Section("Import") {
                Picker("Mode", selection: $importMode) {
                    ForEach(ImportMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                Text(importMode == .merge
                     ? "Add imported items to the existing database."
                     : "Delete all current items before importing.")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    importAction()
                } label: {
                    Label("Import from JSON…", systemImage: "square.and.arrow.down")
                }
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear All Items", systemImage: "trash")
                }
                .confirmationDialog(
                    "Delete all clipboard items?",
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Delete All", role: .destructive) { appState.clearAll() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This cannot be undone. Pinned items will also be removed.")
                }
            }

            if !appState.statusMessage.isEmpty {
                Section {
                    Text(appState.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 4)
    }

    private func exportAction() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "clipboard-export.json"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            appState.exportData(to: url)
        }
    }

    private func importAction() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            appState.importData(from: url, mode: importMode)
        }
    }
}
