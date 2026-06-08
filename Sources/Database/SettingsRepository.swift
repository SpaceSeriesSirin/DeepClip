import Foundation
import GRDB

/// Key/value persistence for application settings.
final class SettingsRepository {
    private let db: AppDatabase

    init(_ db: AppDatabase) {
        self.db = db
    }

    /// Loads every setting, falling back to defaults for any missing keys.
    func loadAll() throws -> [String: String] {
        try db.dbQueue.read { dbc in
            var values: [String: String] = [:]
            for key in SettingKey.allCases {
                values[key.rawValue] = key.defaultValue
            }
            let rows = try Setting.fetchAll(dbc)
            for row in rows {
                values[row.key] = row.value
            }
            return values
        }
    }

    func set(_ key: String, _ value: String) throws {
        try db.dbQueue.write { dbc in
            try Setting(key: key, value: value).save(dbc)
        }
    }

    func setMany(_ pairs: [String: String]) throws {
        try db.dbQueue.write { dbc in
            for (key, value) in pairs {
                try Setting(key: key, value: value).save(dbc)
            }
        }
    }

    func value(for key: String) throws -> String? {
        try db.dbQueue.read { dbc in
            try Setting.fetchOne(dbc, key: key)?.value
        }
    }
}
