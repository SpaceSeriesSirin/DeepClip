import SwiftUI
import AppKit

/// Compact popover shown from the menu-bar icon: quick search + recent items +
/// shortcuts to the main window, settings and quit.
struct MenuBarContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    @State private var recent: [ClipboardItem] = []
    @State private var query: String = ""

    private var filtered: [ClipboardItem] {
        guard !query.isBlank else { return recent }
        let q = query.lowercased()
        return recent.filter {
            ($0.textContent?.lowercased().contains(q) ?? false)
            || ($0.title?.lowercased().contains(q) ?? false)
            || ($0.urlDomain?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            searchField
            Divider()
            content
            Divider()
            footer
        }
        .frame(width: 360, height: 480)
        .onAppear(perform: load)
        .onChange(of: appState.lastUpdated) { _ in load() }
        .contextMenu {
            Button(appState.isMonitoringPaused ? "Resume Monitoring" : "Pause Monitoring") {
                appState.togglePause()
            }
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: appState.isMonitoringPaused ? "pause.circle.fill" : "doc.on.clipboard")
                .foregroundStyle(appState.isMonitoringPaused ? Color.orange : Color.primary)
            Text("CacheMind").font(.headline)
            Spacer()
            Button {
                appState.togglePause()
            } label: {
                Label(
                    appState.isMonitoringPaused ? "Resume Monitoring" : "Pause Monitoring",
                    systemImage: appState.isMonitoringPaused ? "play.fill" : "pause.fill"
                )
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(appState.isMonitoringPaused ? "Resume Monitoring" : "Pause Monitoring")

            Text("\(appState.totalCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(10)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search recent…", text: $query)
                .textFieldStyle(.plain)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            EmptyPlaceholderView(
                title: query.isEmpty ? "No Items Yet" : "No Matches",
                message: query.isEmpty ? "Copied content shows up here." : nil,
                systemImage: "tray"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { item in
                        MenuBarRow(item: item) {
                            appState.copyToClipboard(item)
                        }
                        Divider()
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: WindowID.main)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open", systemImage: "macwindow")
            }

            Button {
                openWindow(id: WindowID.settings)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .keyboardShortcut(",", modifiers: .command)

            Spacer()

            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .buttonStyle(.borderless)
        .padding(10)
    }

    private func load() {
        recent = Array(((try? appState.clipboardRepo.all()) ?? []).prefix(60))
    }
}

/// A compact row used in the menu-bar popover. The text content supports mouse
/// drag selection (not wrapped in a Button); a trailing copy button performs the
/// copy action, as does double-clicking the row.
private struct MenuBarRow: View {
    let item: ClipboardItem
    let onTap: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: item.type.systemImage)
                .foregroundStyle(Color.forContentType(item.type))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.displayTitle)
                    .lineLimit(1)
                    .textSelection(.enabled)
                Text(item.capturedAt.relativeDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            Button(action: onTap) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Copy to clipboard")
            .opacity(hovering ? 1 : 0.4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(hovering ? Color.accentColor.opacity(0.12) : Color.clear)
        .onHover { hovering = $0 }
        .onDrag { item.dragProvider() }
        .onTapGesture(count: 2, perform: onTap)
    }
}
