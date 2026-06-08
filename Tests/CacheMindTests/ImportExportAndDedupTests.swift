import XCTest
@testable import CacheMind

final class ImportExportAndDedupTests: XCTestCase {

    func testExportImportRoundTrip() throws {
        let original = [
            ClipboardItem(contentType: .text, textContent: "hello", sourceApp: "Xcode",
                          isPinned: true, capturedAt: Date(timeIntervalSince1970: 1700000000)),
            ClipboardItem(contentType: .image, imageData: Data([0x89, 0x50, 0x4E, 0x47]),
                          capturedAt: Date(timeIntervalSince1970: 1700000100)),
            ClipboardItem(contentType: .url, textContent: "https://x.com/foo", urlDomain: "x.com",
                          capturedAt: Date(timeIntervalSince1970: 1700000200))
        ]
        let settings = ["maxItems": "750", "aiProvider": "ollama"]

        let data = try ImportExportService.makeExportData(items: original, settings: settings)
        let payload = try ImportExportService.parse(data)

        XCTAssertEqual(payload.version, ImportExportService.formatVersion)
        XCTAssertEqual(payload.settings["maxItems"], "750")
        XCTAssertEqual(payload.items.count, 3)

        let roundTripped = ImportExportService.toClipboardItems(payload)
        XCTAssertEqual(roundTripped.count, 3)

        let text = roundTripped.first { $0.contentType == "text" }
        XCTAssertEqual(text?.textContent, "hello")
        XCTAssertEqual(text?.sourceApp, "Xcode")
        XCTAssertEqual(text?.isPinned, true)

        let image = roundTripped.first { $0.contentType == "image" }
        XCTAssertEqual(image?.imageData, Data([0x89, 0x50, 0x4E, 0x47]))

        let url = roundTripped.first { $0.contentType == "url" }
        XCTAssertEqual(url?.urlDomain, "x.com")
    }

    func testJSONExportIsValidJSON() throws {
        let data = try ImportExportService.makeExportData(
            items: [ClipboardItem(contentType: .text, textContent: "x")],
            settings: [:]
        )
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(obj?["items"])
        XCTAssertNotNil(obj?["version"])
    }

    func testDedupExactAndNearMatch() {
        let service = AIService(config: AIConfig(provider: .none, endpoint: "", model: "", apiKey: ""))
        let existing = [
            ClipboardItem(contentType: .text, textContent: "The quick brown fox jumps"),
            ClipboardItem(contentType: .text, textContent: "Completely different content here")
        ]

        // Exact duplicate.
        let exact = service.isDuplicate(candidate: "The quick brown fox jumps",
                                        candidateEmbedding: nil, against: existing, threshold: 0.85)
        XCTAssertNotNil(exact)

        // Near-duplicate above threshold.
        let near = service.isDuplicate(candidate: "The quick brown fox jumped",
                                       candidateEmbedding: nil, against: existing, threshold: 0.85)
        XCTAssertNotNil(near)

        // Unique content -> not a duplicate.
        let unique = service.isDuplicate(candidate: "Something totally unrelated xyz",
                                         candidateEmbedding: nil, against: existing, threshold: 0.85)
        XCTAssertNil(unique)
    }

    @MainActor
    func testSettingsStoreDefaultsAndPersistence() throws {
        let db = try AppDatabase.makeInMemory()
        let repo = SettingsRepository(db)
        let store = SettingsStore(repository: repo)

        // Defaults from SPEC.
        XCTAssertEqual(store.maxItems, 500)
        XCTAssertEqual(store.cacheDays, 30)
        XCTAssertEqual(store.pollInterval, 0.5)
        XCTAssertEqual(store.aiProvider, .none)
        XCTAssertEqual(store.dedupThreshold, 0.85)

        // Mutating persists to the DB.
        store.maxItems = 999
        XCTAssertEqual(try repo.value(for: "maxItems"), "999")

        // A fresh store reads the persisted value.
        let store2 = SettingsStore(repository: repo)
        XCTAssertEqual(store2.maxItems, 999)
    }
}
