import Foundation
import Combine

/// Observable, strongly-typed view over the key/value `setting` table.
/// Changes are persisted automatically and surfaced via `changeHandler`.
@MainActor
final class SettingsStore: ObservableObject {
    private let repository: SettingsRepository
    private var suppress = false

    /// Invoked after a setting is persisted so AppState can react (reconfigure
    /// AI, restart the monitor, toggle login item, …).
    var changeHandler: ((SettingKey) -> Void)?

    // MARK: General
    @Published var maxItems: Int { didSet { persist(.maxItems, String(maxItems)) } }
    @Published var cacheDays: Int { didSet { persist(.cacheDays, String(cacheDays)) } }
    @Published var launchAtLogin: Bool { didSet { persist(.launchAtLogin, String(launchAtLogin)) } }
    @Published var pollInterval: Double { didSet { persist(.pollInterval, String(pollInterval)) } }
    @Published var ignorePrivacyTypes: Bool { didSet { persist(.ignorePrivacyTypes, String(ignorePrivacyTypes)) } }

    /// Comma-separated bundle identifiers whose copies are never captured.
    @Published var ignoredApps: String { didSet { persist(.ignoredApps, ignoredApps) } }

    /// Minutes after which paused monitoring auto-resumes. 0 = never.
    @Published var autoResumeMinutes: Int { didSet { persist(.autoResumeMinutes, String(autoResumeMinutes)) } }

    // MARK: Global hotkey
    @Published var enableHotkey: Bool { didSet { persist(.enableHotkey, String(enableHotkey)) } }
    @Published var hotkeyKeyCode: Int { didSet { persist(.hotkeyKeyCode, String(hotkeyKeyCode)) } }
    @Published var hotkeyModifiers: Int { didSet { persist(.hotkeyModifiers, String(hotkeyModifiers)) } }
    @Published var hotkeyTarget: String { didSet { persist(.hotkeyTarget, hotkeyTarget) } }

    // MARK: Auto-paste
    @Published var enableAutoPaste: Bool { didSet { persist(.enableAutoPaste, String(enableAutoPaste)) } }

    // MARK: AI configuration
    @Published var aiProvider: AIProviderType { didSet { persist(.aiProvider, aiProvider.rawValue) } }
    @Published var aiEndpoint: String { didSet { persist(.aiEndpoint, aiEndpoint) } }
    @Published var aiModel: String { didSet { persist(.aiModel, aiModel) } }
    @Published var aiApiKey: String { didSet { persist(.aiApiKey, aiApiKey) } }

    // MARK: AI feature toggles
    @Published var enableSemanticSearch: Bool { didSet { persist(.enableSemanticSearch, String(enableSemanticSearch)) } }
    @Published var enableSmartCategory: Bool { didSet { persist(.enableSmartCategory, String(enableSmartCategory)) } }
    @Published var enableSummary: Bool { didSet { persist(.enableSummary, String(enableSummary)) } }
    @Published var enableIntentRecognition: Bool { didSet { persist(.enableIntentRecognition, String(enableIntentRecognition)) } }
    @Published var enableFormatCleaning: Bool { didSet { persist(.enableFormatCleaning, String(enableFormatCleaning)) } }
    @Published var enableDedup: Bool { didSet { persist(.enableDedup, String(enableDedup)) } }
    @Published var enableSmartConvert: Bool { didSet { persist(.enableSmartConvert, String(enableSmartConvert)) } }
    @Published var dedupThreshold: Double { didSet { persist(.dedupThreshold, String(dedupThreshold)) } }

    init(repository: SettingsRepository) {
        self.repository = repository
        let values = (try? repository.loadAll()) ?? [:]

        func str(_ key: SettingKey) -> String { values[key.rawValue] ?? key.defaultValue }
        func int(_ key: SettingKey) -> Int { Int(str(key)) ?? Int(key.defaultValue) ?? 0 }
        func dbl(_ key: SettingKey) -> Double { Double(str(key)) ?? Double(key.defaultValue) ?? 0 }
        func bool(_ key: SettingKey) -> Bool { str(key) == "true" }

        self.maxItems = int(.maxItems)
        self.cacheDays = int(.cacheDays)
        self.launchAtLogin = bool(.launchAtLogin)
        self.pollInterval = dbl(.pollInterval)
        self.ignorePrivacyTypes = bool(.ignorePrivacyTypes)
        self.ignoredApps = str(.ignoredApps)
        self.autoResumeMinutes = int(.autoResumeMinutes)
        self.enableHotkey = bool(.enableHotkey)
        self.hotkeyKeyCode = int(.hotkeyKeyCode)
        self.hotkeyModifiers = int(.hotkeyModifiers)
        self.hotkeyTarget = str(.hotkeyTarget)
        self.enableAutoPaste = bool(.enableAutoPaste)
        self.aiProvider = AIProviderType(rawValue: str(.aiProvider)) ?? .none
        self.aiEndpoint = str(.aiEndpoint)
        self.aiModel = str(.aiModel)
        self.aiApiKey = str(.aiApiKey)
        self.enableSemanticSearch = bool(.enableSemanticSearch)
        self.enableSmartCategory = bool(.enableSmartCategory)
        self.enableSummary = bool(.enableSummary)
        self.enableIntentRecognition = bool(.enableIntentRecognition)
        self.enableFormatCleaning = bool(.enableFormatCleaning)
        self.enableDedup = bool(.enableDedup)
        self.enableSmartConvert = bool(.enableSmartConvert)
        self.dedupThreshold = dbl(.dedupThreshold)
    }

    /// Derived AI configuration consumed by `AIService`.
    var aiConfig: AIConfig {
        AIConfig(
            provider: aiProvider,
            endpoint: aiEndpoint.isBlank ? aiProvider.defaultEndpoint : aiEndpoint,
            model: aiModel,
            apiKey: aiApiKey
        )
    }

    /// Parsed, de-duplicated list of ignored bundle identifiers.
    var ignoredBundleIDs: [String] {
        ignoredApps
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .reduce(into: [String]()) { acc, id in if !acc.contains(id) { acc.append(id) } }
    }

    /// Adds a bundle identifier to the ignore list (no-op if already present).
    func addIgnoredApp(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var list = ignoredBundleIDs
        guard !list.contains(trimmed) else { return }
        list.append(trimmed)
        ignoredApps = list.joined(separator: ",")
    }

    /// Removes a bundle identifier from the ignore list.
    func removeIgnoredApp(_ bundleID: String) {
        let list = ignoredBundleIDs.filter { $0 != bundleID }
        ignoredApps = list.joined(separator: ",")
    }

    /// True if any AI feature toggle that needs a backend is on.
    var anyAIFeatureEnabled: Bool {
        enableSemanticSearch || enableSmartCategory || enableSummary || enableDedup
    }

    private func persist(_ key: SettingKey, _ value: String) {
        guard !suppress else { return }
        do {
            try repository.set(key.rawValue, value)
        } catch {
            AppLogger.database.error("Failed to persist \(key.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
        changeHandler?(key)
    }

    /// Update published properties without triggering persistence / handlers.
    /// Used when syncing state that originates from the system (e.g. login item).
    func applySilently(_ block: (SettingsStore) -> Void) {
        suppress = true
        block(self)
        suppress = false
    }

    /// Replace all values from an imported dictionary (used by Import/Export).
    func reload(from values: [String: String]) {
        applySilently { s in
            func str(_ key: SettingKey) -> String { values[key.rawValue] ?? key.defaultValue }
            func int(_ key: SettingKey) -> Int { Int(str(key)) ?? Int(key.defaultValue) ?? 0 }
            func dbl(_ key: SettingKey) -> Double { Double(str(key)) ?? Double(key.defaultValue) ?? 0 }
            func bool(_ key: SettingKey) -> Bool { str(key) == "true" }

            s.maxItems = int(.maxItems)
            s.cacheDays = int(.cacheDays)
            s.launchAtLogin = bool(.launchAtLogin)
            s.pollInterval = dbl(.pollInterval)
            s.ignorePrivacyTypes = bool(.ignorePrivacyTypes)
            s.ignoredApps = str(.ignoredApps)
            s.autoResumeMinutes = int(.autoResumeMinutes)
            s.enableHotkey = bool(.enableHotkey)
            s.hotkeyKeyCode = int(.hotkeyKeyCode)
            s.hotkeyModifiers = int(.hotkeyModifiers)
            s.hotkeyTarget = str(.hotkeyTarget)
            s.enableAutoPaste = bool(.enableAutoPaste)
            s.aiProvider = AIProviderType(rawValue: str(.aiProvider)) ?? .none
            s.aiEndpoint = str(.aiEndpoint)
            s.aiModel = str(.aiModel)
            s.aiApiKey = str(.aiApiKey)
            s.enableSemanticSearch = bool(.enableSemanticSearch)
            s.enableSmartCategory = bool(.enableSmartCategory)
            s.enableSummary = bool(.enableSummary)
            s.enableIntentRecognition = bool(.enableIntentRecognition)
            s.enableFormatCleaning = bool(.enableFormatCleaning)
            s.enableDedup = bool(.enableDedup)
            s.enableSmartConvert = bool(.enableSmartConvert)
            s.dedupThreshold = dbl(.dedupThreshold)
        }
        objectWillChange.send()
    }
}
