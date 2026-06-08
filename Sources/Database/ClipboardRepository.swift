import Foundation
import GRDB

/// All persistence queries for `ClipboardItem`. Methods are synchronous and
/// thread-safe (GRDB serializes access through the queue).
final class ClipboardRepository {
    private let db: AppDatabase

    init(_ db: AppDatabase) {
        self.db = db
    }

    // MARK: - Writes

    @discardableResult
    func insert(_ item: ClipboardItem) throws -> ClipboardItem {
        try db.dbQueue.write { dbc in
            var copy = item
            try copy.insert(dbc)
            return copy
        }
    }

    func update(_ item: ClipboardItem) throws {
        try db.dbQueue.write { dbc in
            try item.update(dbc)
        }
    }

    /// Inserts when `id == nil`, otherwise updates.
    func save(_ item: ClipboardItem) throws -> ClipboardItem {
        try db.dbQueue.write { dbc in
            var copy = item
            try copy.save(dbc)
            return copy
        }
    }

    func delete(id: Int64) throws {
        _ = try db.dbQueue.write { dbc in
            try ClipboardItem.deleteOne(dbc, key: id)
        }
    }

    func deleteAll() throws {
        _ = try db.dbQueue.write { dbc in
            try ClipboardItem.deleteAll(dbc)
        }
    }

    func setPinned(id: Int64, pinned: Bool) throws {
        try db.dbQueue.write { dbc in
            if var item = try ClipboardItem.fetchOne(dbc, key: id) {
                item.isPinned = pinned
                // Pinned items are exempt from expiry.
                if pinned { item.expiresAt = nil }
                try item.update(dbc)
            }
        }
    }

    // MARK: - Reads

    func fetchOne(id: Int64) throws -> ClipboardItem? {
        try db.dbQueue.read { dbc in
            try ClipboardItem.fetchOne(dbc, key: id)
        }
    }

    func count() throws -> Int {
        try db.dbQueue.read { dbc in
            try ClipboardItem.fetchCount(dbc)
        }
    }

    /// Distinct, non-empty URL domains ordered alphabetically.
    func distinctDomains() throws -> [String] {
        try db.dbQueue.read { dbc in
            try String.fetchAll(dbc, sql: """
                SELECT DISTINCT urlDomain FROM clipboardItem
                WHERE urlDomain IS NOT NULL AND urlDomain <> ''
                ORDER BY urlDomain COLLATE NOCASE ASC
                """)
        }
    }

    /// Per content-type counts, for sidebar badges.
    func countsByType() throws -> [String: Int] {
        try db.dbQueue.read { dbc in
            let rows = try Row.fetchAll(dbc, sql: """
                SELECT contentType, COUNT(*) AS c FROM clipboardItem GROUP BY contentType
                """)
            var result: [String: Int] = [:]
            for row in rows {
                result[row["contentType"]] = row["c"]
            }
            return result
        }
    }

    func pinnedCount() throws -> Int {
        try db.dbQueue.read { dbc in
            try ClipboardItem.filter(ClipboardItem.Columns.isPinned == true).fetchCount(dbc)
        }
    }

    /// Primary list query. Applies category filter + plain-text search + sort.
    /// Pinned items always float to the top regardless of `sort`.
    func fetch(
        selection: SidebarSelection,
        search: String,
        sort: ItemSortOrder
    ) throws -> [ClipboardItem] {
        try db.dbQueue.read { dbc in
            var request = ClipboardItem.all()

            switch selection {
            case .all:
                break
            case .pinned:
                request = request.filter(ClipboardItem.Columns.isPinned == true)
            case .type(let t):
                request = request.filter(ClipboardItem.Columns.contentType == t.rawValue)
            case .domain(let d):
                request = request.filter(ClipboardItem.Columns.urlDomain == d)
            }

            let trimmed = search.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let like = "%\(trimmed)%"
                request = request.filter(
                    ClipboardItem.Columns.textContent.like(like)
                    || ClipboardItem.Columns.title.like(like)
                    || ClipboardItem.Columns.summary.like(like)
                    || ClipboardItem.Columns.urlDomain.like(like)
                )
            }

            // Pinned first, then the requested sort key.
            request = request.order(ClipboardItem.Columns.isPinned.desc)
            switch sort {
            case .dateNewest:
                request = request.order(
                    ClipboardItem.Columns.isPinned.desc,
                    ClipboardItem.Columns.capturedAt.desc
                )
            case .dateOldest:
                request = request.order(
                    ClipboardItem.Columns.isPinned.desc,
                    ClipboardItem.Columns.capturedAt.asc
                )
            case .type:
                request = request.order(
                    ClipboardItem.Columns.isPinned.desc,
                    ClipboardItem.Columns.contentType.asc,
                    ClipboardItem.Columns.capturedAt.desc
                )
            case .alphabetical:
                request = request.order(
                    ClipboardItem.Columns.isPinned.desc,
                    ClipboardItem.Columns.textContent.asc
                )
            }

            return try request.fetchAll(dbc)
        }
    }

    /// Most recent items of a given type — used for dedup comparison windows.
    func recent(ofType type: ContentType, limit: Int) throws -> [ClipboardItem] {
        try db.dbQueue.read { dbc in
            try ClipboardItem
                .filter(ClipboardItem.Columns.contentType == type.rawValue)
                .order(ClipboardItem.Columns.capturedAt.desc)
                .limit(limit)
                .fetchAll(dbc)
        }
    }

    /// Items that carry an embedding vector — used for semantic search.
    func itemsWithEmbedding() throws -> [ClipboardItem] {
        try db.dbQueue.read { dbc in
            try ClipboardItem
                .filter(ClipboardItem.Columns.embedding != nil)
                .fetchAll(dbc)
        }
    }

    func all() throws -> [ClipboardItem] {
        try db.dbQueue.read { dbc in
            try ClipboardItem
                .order(ClipboardItem.Columns.capturedAt.desc)
                .fetchAll(dbc)
        }
    }

    // MARK: - Maintenance

    /// Deletes expired, non-pinned items. Returns number removed.
    @discardableResult
    func deleteExpired(now: Date = Date()) throws -> Int {
        try db.dbQueue.write { dbc in
            let ts = now.timeIntervalSince1970
            return try ClipboardItem
                .filter(ClipboardItem.Columns.isPinned == false)
                .filter(ClipboardItem.Columns.expiresAt != nil)
                .filter(ClipboardItem.Columns.expiresAt < ts)
                .deleteAll(dbc)
        }
    }

    /// Enforces the max item count by trimming the oldest non-pinned rows.
    @discardableResult
    func enforceLimit(maxItems: Int) throws -> Int {
        guard maxItems > 0 else { return 0 }
        return try db.dbQueue.write { dbc in
            let total = try ClipboardItem.fetchCount(dbc)
            guard total > maxItems else { return 0 }
            let overflow = total - maxItems
            // Pick oldest, non-pinned candidates to remove.
            let ids = try Int64.fetchAll(dbc, sql: """
                SELECT id FROM clipboardItem
                WHERE isPinned = 0
                ORDER BY capturedAt ASC
                LIMIT ?
                """, arguments: [overflow])
            guard !ids.isEmpty else { return 0 }
            return try ClipboardItem.deleteAll(dbc, keys: ids)
        }
    }
}
