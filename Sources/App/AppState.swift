import Foundation
import SwiftUI
import Combine

/// The application's central coordinator. Owns the database, services and the
/// observable UI state consumed by every view.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    // Infrastructure
    let appDatabase: AppDatabase
    let clipboardRepo: ClipboardRepository
    let settingsRepo: SettingsRepository
    let settings: SettingsStore
    let monitor: ClipboardMonitor
    let aiService: AIService
    let cleanup: CleanupService

    // UI state
    @Published var items: [ClipboardItem] = []
    @Published var selection: SidebarSelection = .all
    @Published var selectedItemIDs: Set<Int64> = []
    @Published var searchText: String = ""
    @Published var sortOrder: ItemSortOrder = .dateNewest
    @Published var domains: [String] = []
    @Published var typeCounts: [String: Int] = [:]
    @Published var totalCount: Int = 0
    @Published var pinnedCount: Int = 0
    @Published var lastUpdated: Date?
    @Published var statusMessage: String = ""
    @Published var isSemanticSearching = false
    @Published var aiBusyCount = 0
    @Published private(set) var isSemanticResults = false

    /// Mirrors `monitor.isPaused` so SwiftUI views update when paused/resumed.
    @Published private(set) var isMonitoringPaused = false

    private var started = false

    /// Fires to automatically resume monitoring after a pause, when the
    /// `autoResumeMinutes` setting is non-zero.
    private var autoResumeTimer: Timer?

    /// The app that was frontmost just before we summoned our UI, so focus can
    /// be restored when the user dismisses us (and so auto-paste can target it).
    private(set) weak var previousFrontmostApp: NSRunningApplication?

    /// Single-selection accessor kept for compatibility. Derives from
    /// `selectedItemIDs`; setting it replaces the entire selection.
    var selectedItemID: Int64? {
        get { selectedItemIDs.first }
        set { selectedItemIDs = newValue.map { [$0] } ?? [] }
    }

    /// The first selected item, used by the detail view when a single item is
    /// selected. Returns the first item (in list order) within the selection.
    var selectedItem: ClipboardItem? {
        guard !selectedItemIDs.isEmpty else { return nil }
        return items.first { selectedItemIDs.contains($0.id ?? -1) }
    }

    /// All currently-selected items, in list order.
    var selectedItems: [ClipboardItem] {
        items.filter { selectedItemIDs.contains($0.id ?? -1) }
    }

    var aiBusy: Bool { aiBusyCount > 0 }

    // MARK: - Init

    private init() {
        let database: AppDatabase
        do {
            database = try AppDatabase.makeShared()
        } catch {
            AppLogger.app.error("Failed to open database, using in-memory: \(error.localizedDescription, privacy: .public)")
            database = try! AppDatabase.makeInMemory()
        }
        self.appDatabase = database
        self.clipboardRepo = ClipboardRepository(database)
        self.settingsRepo = SettingsRepository(database)
        let settingsStore = SettingsStore(repository: settingsRepo)
        self.settings = settingsStore
        self.monitor = ClipboardMonitor()
        self.monitor.ignorePrivacyTypes = settingsStore.ignorePrivacyTypes
        self.monitor.ignoredBundleIDs = settingsStore.ignoredBundleIDs
        self.aiService = AIService(config: settingsStore.aiConfig)
        self.cleanup = CleanupService(repository: clipboardRepo)

        settings.changeHandler = { [weak self] key in
            self?.handleSettingChange(key)
        }
        monitor.onCapture = { [weak self] content in
            self?.handleCapture(content)
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard !started else { return }
        started = true

        // Sync the login-item state from the system into settings.
        settings.applySilently { $0.launchAtLogin = AutoStartService.isEnabled }

        aiService.update(config: settings.aiConfig)
        cleanup.run(maxItems: settings.maxItems, cacheDays: settings.cacheDays)
        monitor.start(interval: settings.pollInterval)
        configureHotkey()
        reload()
        statusMessage = "Monitoring clipboard…"
    }

    // MARK: - Pause / resume monitoring

    /// Toggles clipboard monitoring between paused and running.
    func togglePause() {
        if monitor.isPaused {
            resumeMonitoring()
        } else {
            pauseMonitoring()
        }
    }

    /// Pauses capture and, when configured, schedules an automatic resume.
    func pauseMonitoring() {
        guard !monitor.isPaused else { return }
        monitor.pause()
        isMonitoringPaused = true
        scheduleAutoResume()
        let minutes = settings.autoResumeMinutes
        statusMessage = minutes > 0
            ? "Monitoring paused — auto-resumes in \(minutes) min"
            : "Monitoring paused"
    }

    func resumeMonitoring() {
        guard monitor.isPaused else { return }
        cancelAutoResume()
        monitor.resume()
        isMonitoringPaused = false
        statusMessage = "Monitoring resumed"
    }

    private func scheduleAutoResume() {
        cancelAutoResume()
        let minutes = settings.autoResumeMinutes
        guard minutes > 0 else { return }
        let interval = TimeInterval(minutes) * 60
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.resumeMonitoring() }
        }
        RunLoop.main.add(timer, forMode: .common)
        autoResumeTimer = timer
    }

    private func cancelAutoResume() {
        autoResumeTimer?.invalidate()
        autoResumeTimer = nil
    }

    // MARK: - Global hotkey

    /// Registers (or unregisters) the global hotkey based on current settings.
    func configureHotkey() {
        HotkeyService.shared.onTrigger = { [weak self] in
            self?.summon()
        }
        guard settings.enableHotkey else {
            HotkeyService.shared.unregister()
            return
        }
        let hotkey = HotkeyService.Hotkey(
            keyCode: settings.hotkeyKeyCode,
            modifiers: NSEvent.ModifierFlags(rawValue: UInt(settings.hotkeyModifiers))
        )
        HotkeyService.shared.update(to: hotkey)
    }

    /// Brings the ClipboardManager UI to the front from any app. Remembers the
    /// previously-frontmost app so focus can later be restored.
    func summon() {
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        switch settings.hotkeyTarget {
        case "popover":
            summonPopover()
        case "quickpanel":
            summonQuickPanel()
        default:
            summonMainWindow()
        }
    }

    private func summonQuickPanel() {
        // The quick panel is a non-activating floating overlay: it intentionally
        // does NOT call NSApp.activate, so the previous app keeps focus and the
        // synthetic paste lands there.
        reload()
        QuickPanelController.shared.show(appState: self)
    }

    private func summonMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        // Reuse an existing main window if present; otherwise ask SwiftUI to open one.
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == WindowID.main }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            NotificationCenter.default.post(name: .summonMainWindow, object: nil)
        }
    }

    private func summonPopover() {
        NSApp.activate(ignoringOtherApps: true)
        // Click the menu-bar status item to toggle the MenuBarExtra popover open.
        if let button = NSApp.windows
            .compactMap({ $0.value(forKey: "statusItem") as? NSStatusItem })
            .first?.button {
            button.performClick(nil)
        } else {
            // Fall back to the main window if the status item can't be found.
            summonMainWindow()
        }
    }

    /// Restores focus to the app that was frontmost before we were summoned.
    func restorePreviousApp() {
        previousFrontmostApp?.activate(options: [])
        previousFrontmostApp = nil
    }

    // MARK: - Capture pipeline

    private func handleCapture(_ content: CapturedContent) {
        guard var item = makeItem(from: content) else { return }

        // Smart dedup (text-based, synchronous) before persisting.
        if settings.enableDedup, let text = item.textContent, !text.isBlank {
            if let existing = findDuplicate(text: text, type: item.type) {
                bump(existing, expiresAt: item.expiresAt)
                return
            }
        }

        do {
            item = try clipboardRepo.insert(item)
            lastUpdated = Date()
            cleanup.run(maxItems: settings.maxItems, cacheDays: settings.cacheDays)
            reload()
            enrichWithAI(item)
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
            AppLogger.clipboard.error("Insert failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makeItem(from content: CapturedContent) -> ClipboardItem? {
        let now = Date()
        let expiry = CleanupService.expiryDate(from: now, cacheDays: settings.cacheDays)

        if let imageData = content.imageData {
            let png = ImageHelper.normalizedPNG(from: imageData) ?? imageData
            var meta: String?
            if let dims = ImageHelper.dimensions(of: png) {
                meta = "{\"width\":\(dims.width),\"height\":\(dims.height)}"
            }
            return ClipboardItem(
                contentType: .image,
                imageData: png,
                sourceApp: content.sourceApp,
                capturedAt: now,
                expiresAt: expiry,
                metadata: meta
            )
        }

        guard var text = content.text?.trimmed, !text.isEmpty else { return nil }

        var type = ContentClassifier.classify(text: text)
        // A declared URL pasteboard type is a strong hint.
        if type != .url, let declared = content.declaredURL, URLHelper.isURL(declared) {
            type = .url
            text = declared
        }

        if settings.enableFormatCleaning {
            text = type == .code ? FormatCleaner.cleanCode(text) : FormatCleaner.clean(text)
        }

        let domain = type == .url ? URLHelper.domain(from: text) : nil

        return ClipboardItem(
            contentType: type,
            textContent: text,
            urlDomain: domain,
            sourceApp: content.sourceApp,
            capturedAt: now,
            expiresAt: expiry
        )
    }

    private func findDuplicate(text: String, type: ContentType) -> ClipboardItem? {
        let recent = (try? clipboardRepo.recent(ofType: type, limit: 80)) ?? []
        return aiService.isDuplicate(
            candidate: text,
            candidateEmbedding: nil,
            against: recent,
            threshold: settings.dedupThreshold
        )
    }

    private func bump(_ item: ClipboardItem, expiresAt: Date?) {
        var updated = item
        updated.capturedAt = Date()
        if !updated.isPinned { updated.expiresAt = expiresAt }
        try? clipboardRepo.update(updated)
        lastUpdated = Date()
        statusMessage = "Duplicate detected — moved existing item to top"
        reload()
    }

    // MARK: - AI enrichment

    private func enrichWithAI(_ item: ClipboardItem) {
        guard aiService.isAvailable, item.type != .image else { return }
        guard let text = item.textContent, !text.isBlank else { return }

        let needsEmbedding = settings.enableSemanticSearch || settings.enableDedup
        let needsTitle = settings.enableSummary
        let needsCategory = settings.enableSmartCategory
        guard needsEmbedding || needsTitle || needsCategory else { return }

        aiBusyCount += 1
        Task { [weak self] in
            guard let self else { return }
            var updated = item

            if needsCategory, let type = try? await self.aiService.classify(text) {
                updated.contentType = type.rawValue
                updated.urlDomain = type == .url ? URLHelper.domain(from: text) : nil
            }
            if needsTitle, let ts = try? await self.aiService.generateTitleAndSummary(for: text) {
                updated.title = ts.title
                updated.summary = ts.summary
            }
            if needsEmbedding, let vector = try? await self.aiService.embed(text) {
                updated.embedding = VectorMath.encode(vector)
            }

            try? self.clipboardRepo.update(updated)
            self.aiBusyCount -= 1
            self.reload()
        }
    }

    // MARK: - Loading / search

    func reload() {
        isSemanticResults = false
        do {
            items = try clipboardRepo.fetch(selection: selection, search: searchText, sort: sortOrder)
            domains = try clipboardRepo.distinctDomains()
            typeCounts = try clipboardRepo.countsByType()
            totalCount = try clipboardRepo.count()
            pinnedCount = try clipboardRepo.pinnedCount()
            reconcileSelection()
        } catch {
            statusMessage = "Load failed: \(error.localizedDescription)"
        }
    }

    /// Entry point used by the search field. Chooses semantic vs. plain search.
    func runSearch() {
        if settings.enableSemanticSearch && aiService.isAvailable && !searchText.isBlank {
            runSemanticSearch()
        } else {
            reload()
        }
    }

    private func runSemanticSearch() {
        let query = searchText
        let candidates = (try? clipboardRepo.fetch(selection: selection, search: "", sort: sortOrder)) ?? []
        let withEmbeddings = candidates.filter { $0.embedding != nil }
        guard !withEmbeddings.isEmpty else {
            statusMessage = "No embedded items yet — falling back to text search"
            reload()
            return
        }
        isSemanticSearching = true
        Task { [weak self] in
            guard let self else { return }
            do {
                let ranked = try await self.aiService.semanticRank(query: query, items: withEmbeddings)
                let top = ranked.filter { $0.score > 0.2 }.prefix(50).map { $0.item }
                self.items = Array(top)
                self.isSemanticResults = true
                self.statusMessage = "Semantic search: \(top.count) result(s)"
                self.reconcileSelection()
            } catch {
                self.statusMessage = "Semantic search failed: \(error.localizedDescription)"
                self.reload()
            }
            self.isSemanticSearching = false
        }
    }

    private func reconcileSelection() {
        // Drop any selected IDs that no longer exist in the current list.
        let valid = Set(items.compactMap { $0.id })
        let filtered = selectedItemIDs.intersection(valid)
        if filtered != selectedItemIDs {
            selectedItemIDs = filtered
        }
        // If nothing remains selected, fall back to the first item.
        if selectedItemIDs.isEmpty, let first = items.first?.id {
            selectedItemIDs = [first]
        }
    }

    // MARK: - Item actions

    func copyToClipboard(_ item: ClipboardItem) {
        PasteboardWriter.copy(item)
        monitor.acknowledgeCurrentChange()
        statusMessage = "Copied to clipboard"
    }

    /// Writes the item to the pasteboard and, when auto-paste is enabled and an
    /// appropriate previous app + Accessibility permission are available,
    /// simulates a paste into that app. Falls back to a plain copy otherwise.
    ///
    /// - Parameter plainText: when true, pastes using "Paste and Match Style"
    ///   (⌥⇧⌘V) so styling from the source is dropped.
    func paste(_ item: ClipboardItem, plainText: Bool = false) {
        copyToClipboard(item)

        guard settings.enableAutoPaste, let app = previousFrontmostApp, !app.isTerminated else {
            return
        }
        guard AutoPasteService.hasPermission else {
            AutoPasteService.requestPermission()
            statusMessage = "Grant Accessibility permission to enable auto-paste"
            return
        }

        if plainText {
            AutoPasteService.pastePlainText(previousApp: app)
            statusMessage = "Pasted (plain text)"
        } else {
            AutoPasteService.pasteIntoPreviousApp(previousApp: app)
            statusMessage = "Pasted into \(app.localizedName ?? "previous app")"
        }
    }

    func togglePin(_ item: ClipboardItem) {
        guard let id = item.id else { return }
        try? clipboardRepo.setPinned(id: id, pinned: !item.isPinned)
        reload()
    }

    func delete(_ item: ClipboardItem) {
        guard let id = item.id else { return }
        try? clipboardRepo.delete(id: id)
        reload()
    }

    func deleteSelected() {
        let ids = selectedItemIDs
        guard !ids.isEmpty else { return }
        for id in ids {
            try? clipboardRepo.delete(id: id)
        }
        selectedItemIDs = []
        reload()
        statusMessage = ids.count == 1 ? "Item deleted" : "\(ids.count) items deleted"
    }

    /// Pins or unpins every selected item. When the selection contains a mix of
    /// pinned and unpinned items, pins all of them.
    func togglePinSelected() {
        let selected = selectedItems
        guard !selected.isEmpty else { return }
        let shouldPin = selected.contains { !$0.isPinned }
        for item in selected {
            guard let id = item.id else { continue }
            try? clipboardRepo.setPinned(id: id, pinned: shouldPin)
        }
        reload()
        statusMessage = shouldPin
            ? "Pinned \(selected.count) item(s)"
            : "Unpinned \(selected.count) item(s)"
    }

    /// Copies all selected items to the clipboard as a single newline-joined
    /// text payload (images and binary items are skipped).
    func copySelected() {
        let selected = selectedItems
        guard !selected.isEmpty else { return }
        if selected.count == 1 {
            copyToClipboard(selected[0])
            return
        }
        let texts = selected.compactMap { $0.textContent }
        guard !texts.isEmpty else {
            statusMessage = "Nothing to copy from selection"
            return
        }
        PasteboardWriter.copyText(texts.joined(separator: "\n"))
        monitor.acknowledgeCurrentChange()
        statusMessage = "Copied \(texts.count) item(s) to clipboard"
    }

    /// Selects every item currently shown in the list.
    func selectAll() {
        selectedItemIDs = Set(items.compactMap { $0.id })
    }

    func clearAll() {
        try? clipboardRepo.deleteAll()
        reload()
        statusMessage = "All items cleared"
    }

    // MARK: - Smart convert

    /// Applies a conversion to the selected item and copies the result to the
    /// clipboard (which the monitor then captures as a fresh item).
    @discardableResult
    func applyConversion(_ op: SmartConvert.Operation, to item: ClipboardItem) -> Bool {
        guard let text = item.textContent else { return false }
        guard let result = SmartConvert.apply(op, to: text) else {
            statusMessage = "Conversion failed (\(op.displayName))"
            return false
        }
        PasteboardWriter.copyText(result)
        statusMessage = "\(op.displayName) → copied result"
        return true
    }

    // MARK: - Intent recognition

    func suggestions(for item: ClipboardItem) -> [ActionSuggestion] {
        guard settings.enableIntentRecognition, let text = item.textContent else { return [] }
        return IntentRecognizer.analyze(text)
    }

    // MARK: - Import / export

    func exportData(to url: URL) {
        do {
            let allItems = try clipboardRepo.all()
            let settingsDict = try settingsRepo.loadAll()
            let data = try ImportExportService.makeExportData(items: allItems, settings: settingsDict)
            try data.write(to: url)
            statusMessage = "Exported \(allItems.count) items to \(url.lastPathComponent)"
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func importData(from url: URL, mode: ImportMode) {
        do {
            let data = try Data(contentsOf: url)
            let payload = try ImportExportService.parse(data)
            if mode == .replace {
                try clipboardRepo.deleteAll()
            }
            let items = ImportExportService.toClipboardItems(payload)
            for item in items {
                _ = try clipboardRepo.insert(item)
            }
            try settingsRepo.setMany(payload.settings)
            settings.reload(from: payload.settings)
            aiService.update(config: settings.aiConfig)
            monitor.ignoredBundleIDs = settings.ignoredBundleIDs
            monitor.restart(interval: settings.pollInterval)
            reload()
            statusMessage = "Imported \(items.count) items (\(mode.displayName))"
        } catch {
            statusMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - AI connection test

    func testAIConnection() async -> String {
        do {
            return try await aiService.testConnection()
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Settings reactions

    private func handleSettingChange(_ key: SettingKey) {
        switch key {
        case .pollInterval:
            monitor.restart(interval: settings.pollInterval)
        case .ignorePrivacyTypes:
            monitor.ignorePrivacyTypes = settings.ignorePrivacyTypes
        case .ignoredApps:
            monitor.ignoredBundleIDs = settings.ignoredBundleIDs
        case .autoResumeMinutes:
            // If currently paused, reschedule with the new interval.
            if monitor.isPaused { scheduleAutoResume() }
        case .aiProvider, .aiEndpoint, .aiModel, .aiApiKey:
            aiService.update(config: settings.aiConfig)
        case .launchAtLogin:
            do {
                try AutoStartService.setEnabled(settings.launchAtLogin)
            } catch {
                statusMessage = "Login item error: \(error.localizedDescription)"
                settings.applySilently { $0.launchAtLogin = AutoStartService.isEnabled }
            }
        case .maxItems, .cacheDays:
            cleanup.run(maxItems: settings.maxItems, cacheDays: settings.cacheDays)
            reload()
        case .enableHotkey, .hotkeyKeyCode, .hotkeyModifiers:
            configureHotkey()
        default:
            break
        }
    }
}
