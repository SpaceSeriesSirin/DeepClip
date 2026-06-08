import Foundation

enum ImportMode: String, CaseIterable, Identifiable {
    case merge
    case replace
    var id: String { rawValue }
    var displayName: String { self == .merge ? "Merge" : "Replace All" }
}

/// JSON import/export of items + settings (SPEC Phase 5). Images are stored as
/// base64; embeddings are preserved as base64 too.
enum ImportExportService {

    static let formatVersion = 1

    struct ExportPayload: Codable {
        var version: Int
        var exportedAt: Date
        var settings: [String: String]
        var items: [ExportItem]
    }

    struct ExportItem: Codable {
        var contentType: String
        var textContent: String?
        var imageBase64: String?
        var urlDomain: String?
        var sourceApp: String?
        var title: String?
        var summary: String?
        var embeddingBase64: String?
        var isPinned: Bool
        var isDuplicate: Bool
        var capturedAt: Date
        var expiresAt: Date?
        var metadata: String?
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    private static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    // MARK: - Export

    static func makeExportData(items: [ClipboardItem], settings: [String: String]) throws -> Data {
        let exportItems = items.map { item in
            ExportItem(
                contentType: item.contentType,
                textContent: item.textContent,
                imageBase64: item.imageData?.base64EncodedString(),
                urlDomain: item.urlDomain,
                sourceApp: item.sourceApp,
                title: item.title,
                summary: item.summary,
                embeddingBase64: item.embedding?.base64EncodedString(),
                isPinned: item.isPinned,
                isDuplicate: item.isDuplicate,
                capturedAt: item.capturedAt,
                expiresAt: item.expiresAt,
                metadata: item.metadata
            )
        }
        let payload = ExportPayload(
            version: formatVersion,
            exportedAt: Date(),
            settings: settings,
            items: exportItems
        )
        return try encoder().encode(payload)
    }

    // MARK: - Import

    static func parse(_ data: Data) throws -> ExportPayload {
        try decoder().decode(ExportPayload.self, from: data)
    }

    static func toClipboardItems(_ payload: ExportPayload) -> [ClipboardItem] {
        payload.items.map { ei in
            ClipboardItem(
                id: nil,
                contentType: ContentType(rawValue: ei.contentType) ?? .text,
                textContent: ei.textContent,
                imageData: ei.imageBase64.flatMap { Data(base64Encoded: $0) },
                urlDomain: ei.urlDomain,
                sourceApp: ei.sourceApp,
                title: ei.title,
                summary: ei.summary,
                embedding: ei.embeddingBase64.flatMap { Data(base64Encoded: $0) },
                isPinned: ei.isPinned,
                isDuplicate: ei.isDuplicate,
                capturedAt: ei.capturedAt,
                expiresAt: ei.expiresAt,
                metadata: ei.metadata
            )
        }
    }
}
