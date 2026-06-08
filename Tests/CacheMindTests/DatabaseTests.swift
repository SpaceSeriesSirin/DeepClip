import XCTest
@testable import CacheMind

final class DatabaseTests: XCTestCase {

    private func makeRepo() throws -> ClipboardRepository {
        let db = try AppDatabase.makeInMemory()
        return ClipboardRepository(db)
    }

    func testInsertAndFetch() throws {
        let repo = try makeRepo()
        let item = ClipboardItem(contentType: .text, textContent: "hello")
        let saved = try repo.insert(item)
        XCTAssertNotNil(saved.id)
        XCTAssertEqual(try repo.count(), 1)

        let fetched = try repo.fetchOne(id: saved.id!)
        XCTAssertEqual(fetched?.textContent, "hello")
    }

    func testEnforceLimitTrimsOldestNonPinned() throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 1_000_000)
        for i in 0..<10 {
            let item = ClipboardItem(
                contentType: .text,
                textContent: "item \(i)",
                capturedAt: base.addingTimeInterval(Double(i))
            )
            _ = try repo.insert(item)
        }
        // Pin the oldest so it survives trimming.
        let all = try repo.all().sorted { $0.capturedAt < $1.capturedAt }
        try repo.setPinned(id: all.first!.id!, pinned: true)

        let removed = try repo.enforceLimit(maxItems: 5)
        XCTAssertEqual(removed, 5)
        XCTAssertEqual(try repo.count(), 5)

        // Pinned oldest item must still be present.
        XCTAssertNotNil(try repo.fetchOne(id: all.first!.id!))
    }

    func testDeleteExpiredKeepsPinned() throws {
        let repo = try makeRepo()
        let past = Date().addingTimeInterval(-1000)

        var expired = ClipboardItem(contentType: .text, textContent: "old",
                                    capturedAt: past, expiresAt: past)
        expired = try repo.insert(expired)

        var pinnedExpired = ClipboardItem(contentType: .text, textContent: "pinned old",
                                          isPinned: true, capturedAt: past, expiresAt: past)
        pinnedExpired = try repo.insert(pinnedExpired)

        let removed = try repo.deleteExpired()
        XCTAssertEqual(removed, 1)
        XCTAssertNil(try repo.fetchOne(id: expired.id!))
        XCTAssertNotNil(try repo.fetchOne(id: pinnedExpired.id!))
    }

    func testDistinctDomainsAndCounts() throws {
        let repo = try makeRepo()
        _ = try repo.insert(ClipboardItem(contentType: .url, textContent: "https://x.com/a", urlDomain: "x.com"))
        _ = try repo.insert(ClipboardItem(contentType: .url, textContent: "https://x.com/b", urlDomain: "x.com"))
        _ = try repo.insert(ClipboardItem(contentType: .url, textContent: "https://github.com/c", urlDomain: "github.com"))
        _ = try repo.insert(ClipboardItem(contentType: .text, textContent: "plain"))

        let domains = try repo.distinctDomains()
        XCTAssertEqual(domains, ["github.com", "x.com"])

        let counts = try repo.countsByType()
        XCTAssertEqual(counts["url"], 3)
        XCTAssertEqual(counts["text"], 1)
    }

    func testFetchFiltersByDomainAndPinnedFloatsToTop() throws {
        let repo = try makeRepo()
        let base = Date(timeIntervalSince1970: 2_000_000)
        _ = try repo.insert(ClipboardItem(contentType: .url, textContent: "https://x.com/old",
                                          urlDomain: "x.com", capturedAt: base))
        var newer = ClipboardItem(contentType: .url, textContent: "https://x.com/new",
                                  urlDomain: "x.com", capturedAt: base.addingTimeInterval(100))
        newer = try repo.insert(newer)
        // Pin the older one; it must come first despite being older.
        let xItems = try repo.fetch(selection: .domain("x.com"), search: "", sort: .dateNewest)
        XCTAssertEqual(xItems.count, 2)
        let oldId = xItems.first(where: { $0.textContent?.contains("old") == true })!.id!
        try repo.setPinned(id: oldId, pinned: true)

        let sorted = try repo.fetch(selection: .domain("x.com"), search: "", sort: .dateNewest)
        XCTAssertTrue(sorted.first!.isPinned)
        XCTAssertEqual(sorted.first!.id, oldId)
    }

    func testSearchFilter() throws {
        let repo = try makeRepo()
        _ = try repo.insert(ClipboardItem(contentType: .text, textContent: "the quick brown fox"))
        _ = try repo.insert(ClipboardItem(contentType: .text, textContent: "lazy dog"))
        let results = try repo.fetch(selection: .all, search: "quick", sort: .dateNewest)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.textContent, "the quick brown fox")
    }
}
