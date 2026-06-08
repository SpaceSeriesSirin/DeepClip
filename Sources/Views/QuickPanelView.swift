import SwiftUI
import AppKit

/// A floating `NSPanel` subclass that can accept keyboard input while remaining
/// non-activating, so the previously-focused application keeps its focus and the
/// synthetic paste lands there.
private final class QuickPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Holds the mutable UI state of the quick panel (search text + selection) so it
/// can be driven both by SwiftUI and by an AppKit key-event monitor. This avoids
/// SwiftUI's `onKeyPress`, which is only available on macOS 14+.
@MainActor
final class QuickPanelModel: ObservableObject {
    @Published var searchText = "" {
        didSet { if searchText != oldValue { selectedIndex = 0 } }
    }
    @Published var selectedIndex = 0

    let appState: AppState
    let onDismiss: () -> Void

    init(appState: AppState, onDismiss: @escaping () -> Void) {
        self.appState = appState
        self.onDismiss = onDismiss
    }

    var filteredItems: [ClipboardItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return appState.items }
        let needle = trimmed.lowercased()
        return appState.items.filter { item in
            if let text = item.textContent, text.lowercased().contains(needle) { return true }
            if let title = item.title, title.lowercased().contains(needle) { return true }
            if let domain = item.urlDomain, domain.lowercased().contains(needle) { return true }
            if let app = item.sourceApp, app.lowercased().contains(needle) { return true }
            return false
        }
    }

    func moveSelection(_ delta: Int) {
        let count = filteredItems.count
        guard count > 0 else { return }
        selectedIndex = max(0, min(count - 1, selectedIndex + delta))
    }

    func pasteSelected(plainText: Bool = false) {
        paste(at: selectedIndex, plainText: plainText)
    }

    func pasteByNumber(_ number: Int) {
        // ⌘1 = first item, … ⌘9 = ninth item.
        paste(at: number - 1)
    }

    func paste(at index: Int, plainText: Bool = false) {
        guard let item = filteredItems[safe: index] else { return }
        if appState.settings.enableAutoPaste {
            appState.paste(item, plainText: plainText)
        } else {
            appState.copyToClipboard(item)
        }
        onDismiss()
    }
}

/// Manages the lifecycle of the keyboard-first quick paste overlay.
@MainActor
final class QuickPanelController {
    static let shared = QuickPanelController()

    private var panel: QuickPanel?
    private var model: QuickPanelModel?
    private var keyMonitor: Any?
    private var isVisible = false

    private init() {}

    func show(appState: AppState) {
        // Toggle behaviour: pressing the hotkey again dismisses an open panel.
        if isVisible {
            hide()
            return
        }

        let model = QuickPanelModel(appState: appState) { [weak self] in
            self?.hide()
        }
        self.model = model

        let panel: QuickPanel
        if let existing = self.panel {
            panel = existing
        } else {
            panel = QuickPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.animationBehavior = .utilityWindow
            self.panel = panel
        }

        // Position near the center of the active screen.
        let screen = NSScreen.main ?? NSScreen.screens.first
        if let screenRect = screen?.visibleFrame {
            let x = screenRect.midX - 210
            let y = screenRect.midY - 250
            panel.setFrame(NSRect(x: x, y: y, width: 420, height: 500), display: false)
        }

        let quickView = QuickPanelView(model: model)
        panel.contentView = NSHostingView(rootView: quickView)
        panel.makeKeyAndOrderFront(nil)
        isVisible = true

        installKeyMonitor()
    }

    func hide() {
        removeKeyMonitor()
        panel?.orderOut(nil)
        model = nil
        isVisible = false
    }

    // MARK: - Keyboard handling (macOS 13 compatible)

    private func installKeyMonitor() {
        removeKeyMonitor()
        // Local key-down monitors are always delivered on the main thread, so it
        // is safe to touch main-actor state synchronously here.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                guard let model = QuickPanelController.shared.model else { return event }
                return QuickPanelController.shared.handle(event, model: model) ? nil : event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    /// Returns `true` if the key event was consumed (and should be swallowed),
    /// or `false` to let it propagate (so typing still reaches the search field).
    private func handle(_ event: NSEvent, model: QuickPanelModel) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch event.keyCode {
        case 53: // Escape
            model.onDismiss()
            return true
        case 36, 76: // Return / keypad Enter
            model.pasteSelected(plainText: mods.contains(.option))
            return true
        case 126: // Up arrow
            model.moveSelection(-1)
            return true
        case 125: // Down arrow
            model.moveSelection(1)
            return true
        default:
            break
        }

        // ⌘1–⌘9 → instant paste by position.
        if mods.contains(.command),
           let chars = event.charactersIgnoringModifiers,
           let digit = Int(chars), (1...9).contains(digit) {
            model.pasteByNumber(digit)
            return true
        }

        return false
    }
}

/// The keyboard-first overlay content: a search field, a navigable item list and
/// a footer of keyboard hints.
struct QuickPanelView: View {
    @ObservedObject var model: QuickPanelModel
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            itemList
            Divider()
            footer
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .frame(width: 420, height: 500)
        .onAppear { searchFocused = true }
    }

    // MARK: - Subviews

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search or type to filter…", text: $model.searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit { model.pasteSelected() }
        }
        .padding(12)
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if model.filteredItems.isEmpty {
                        Text("No items")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(Array(model.filteredItems.enumerated()), id: \.element.id) { idx, item in
                            QuickPanelRow(item: item, index: idx, isSelected: idx == model.selectedIndex)
                                .id(idx)
                                .contentShape(Rectangle())
                                .onTapGesture { model.paste(at: idx) }
                        }
                    }
                }
            }
            .onChange(of: model.selectedIndex) { newValue in
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            hint("↵", "Paste")
            hint("⌘1-9", "Quick")
            hint("⌥↵", "Plain")
            Spacer()
            hint("Esc", "Dismiss")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).fontWeight(.semibold)
            Text(label)
        }
    }
}

/// A compact row tuned for the quick panel: numeric shortcut badge, icon, title
/// and a one-line preview, with selection highlighting.
struct QuickPanelRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            badge
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayTitle)
                    .lineLimit(1)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                HStack(spacing: 6) {
                    Text(item.type.displayName)
                    if let domain = item.urlDomain, !domain.isEmpty {
                        Text(domain).lineLimit(1)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if item.isPinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor.opacity(0.22) : Color.clear)
                .padding(.horizontal, 6)
        )
    }

    @ViewBuilder
    private var badge: some View {
        if index < 9 {
            Text("⌘\(index + 1)")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
        } else {
            Color.clear.frame(width: 26)
        }
    }

    @ViewBuilder
    private var icon: some View {
        if item.type == .image, let data = item.imageData, let image = ImageHelper.image(from: data) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.forContentType(item.type).opacity(0.15))
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: item.type.systemImage)
                        .font(.caption)
                        .foregroundStyle(Color.forContentType(item.type))
                )
        }
    }
}
