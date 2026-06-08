import Foundation

/// Enforces retention policy: removes expired items and trims to the max count.
/// Pinned items are never auto-removed (SPEC Phase 2.3).
final class CleanupService {
    private let repository: ClipboardRepository

    init(repository: ClipboardRepository) {
        self.repository = repository
    }

    @discardableResult
    func run(maxItems: Int, cacheDays: Int) -> (expired: Int, trimmed: Int) {
        var expired = 0
        var trimmed = 0
        do {
            expired = try repository.deleteExpired()
            trimmed = try repository.enforceLimit(maxItems: maxItems)
            if expired > 0 || trimmed > 0 {
                AppLogger.clipboard.info("Cleanup removed \(expired) expired + \(trimmed) overflow items")
            }
        } catch {
            AppLogger.clipboard.error("Cleanup failed: \(error.localizedDescription, privacy: .public)")
        }
        return (expired, trimmed)
    }

    /// Computes an expiry date for a freshly captured item.
    static func expiryDate(from capturedAt: Date, cacheDays: Int) -> Date? {
        guard cacheDays > 0 else { return nil }
        return Calendar.current.date(byAdding: .day, value: cacheDays, to: capturedAt)
    }
}
