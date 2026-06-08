import Foundation
import GRDB

/// Key/value persistence row backing the `setting` table.
struct Setting: Codable, FetchableRecord, PersistableRecord, Equatable {
    var key: String
    var value: String

    static let databaseTableName = "setting"

    enum Columns {
        static let key = Column("key")
        static let value = Column("value")
    }
}

/// Canonical list of setting keys and their defaults (see SPEC.md table).
enum SettingKey: String, CaseIterable {
    case maxItems
    case cacheDays
    case launchAtLogin
    case aiProvider
    case aiEndpoint
    case aiModel
    case aiApiKey
    case enableSemanticSearch
    case enableSmartCategory
    case enableSummary
    case enableIntentRecognition
    case enableFormatCleaning
    case enableDedup
    case enableSmartConvert
    case dedupThreshold
    case pollInterval
    case ignorePrivacyTypes
    case enableHotkey
    case hotkeyKeyCode
    case hotkeyModifiers
    case hotkeyTarget
    case enableAutoPaste
    case ignoredApps
    case autoResumeMinutes

    var defaultValue: String {
        switch self {
        case .maxItems: return "500"
        case .cacheDays: return "30"
        case .launchAtLogin: return "false"
        case .aiProvider: return "none"
        case .aiEndpoint: return "http://localhost:8080"
        case .aiModel: return "qwen3-0.6b-embedding"
        case .aiApiKey: return ""
        case .enableSemanticSearch: return "false"
        case .enableSmartCategory: return "false"
        case .enableSummary: return "false"
        case .enableIntentRecognition: return "false"
        case .enableFormatCleaning: return "false"
        case .enableDedup: return "false"
        case .enableSmartConvert: return "false"
        case .dedupThreshold: return "0.85"
        case .pollInterval: return "0.5"
        case .ignorePrivacyTypes: return "true"
        case .enableHotkey: return "true"
        case .hotkeyKeyCode: return "9"        // kVK_ANSI_V
        case .hotkeyModifiers: return "1179648" // .command + .shift (NSEvent.ModifierFlags rawValue)
        case .hotkeyTarget: return "main"      // "main" window, "popover" or "quickpanel"
        case .enableAutoPaste: return "true"
        case .ignoredApps: return ""
        case .autoResumeMinutes: return "0"
        }
    }
}
