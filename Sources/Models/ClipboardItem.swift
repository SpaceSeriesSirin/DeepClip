import Foundation
import GRDB
import UniformTypeIdentifiers

/// A single captured clipboard entry. Mirrors the `clipboardItem` table.
struct ClipboardItem: Identifiable, Codable, Equatable, Hashable {
    var id: Int64?
    var contentType: String
    var textContent: String?
    var imageData: Data?
    var urlDomain: String?
    var sourceApp: String?
    var title: String?
    var summary: String?
    var embedding: Data?
    var isPinned: Bool = false
    var isDuplicate: Bool = false
    var capturedAt: Date
    var expiresAt: Date?
    var metadata: String?

    init(
        id: Int64? = nil,
        contentType: ContentType,
        textContent: String? = nil,
        imageData: Data? = nil,
        urlDomain: String? = nil,
        sourceApp: String? = nil,
        title: String? = nil,
        summary: String? = nil,
        embedding: Data? = nil,
        isPinned: Bool = false,
        isDuplicate: Bool = false,
        capturedAt: Date = Date(),
        expiresAt: Date? = nil,
        metadata: String? = nil
    ) {
        self.id = id
        self.contentType = contentType.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.urlDomain = urlDomain
        self.sourceApp = sourceApp
        self.title = title
        self.summary = summary
        self.embedding = embedding
        self.isPinned = isPinned
        self.isDuplicate = isDuplicate
        self.capturedAt = capturedAt
        self.expiresAt = expiresAt
        self.metadata = metadata
    }
}

// MARK: - Convenience accessors

extension ClipboardItem {
    /// Strongly typed content type with a safe fallback to `.text`.
    var type: ContentType {
        ContentType(rawValue: contentType) ?? .text
    }

    /// A short, single-line label used in list rows. Prefers an AI title.
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        switch type {
        case .image:
            return "Image"
        default:
            let text = (textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { return "(empty)" }
            let firstLine = text.components(separatedBy: .newlines).first ?? text
            return String(firstLine.prefix(120))
        }
    }

    /// A best-effort preview snippet for list rows.
    var previewText: String {
        let text = (textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return String(text.prefix(300))
    }

    /// Decoded embedding vector, if present.
    var embeddingVector: [Double]? {
        guard let embedding else { return nil }
        return VectorMath.decode(embedding)
    }
}

// MARK: - Drag & drop

extension ClipboardItem {
    /// Builds an `NSItemProvider` so the item can be dragged out of the app and
    /// dropped into other apps (text fields, Finder, browsers, …).
    ///
    /// - Image items provide PNG (and TIFF) image data.
    /// - URL items provide both a `URL` (so browsers/Finder accept the drop) and
    ///   the plain-text representation.
    /// - All other text-bearing items provide plain text.
    func dragProvider() -> NSItemProvider {
        if type == .image, let data = imageData {
            let provider = NSItemProvider()
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.png.identifier,
                visibility: .all
            ) { completion in
                completion(data, nil)
                return nil
            }
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.tiff.identifier,
                visibility: .all
            ) { completion in
                completion(data, nil)
                return nil
            }
            return provider
        }

        if type == .url,
           let text = textContent,
           let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme != nil {
            // Register the URL first so receivers that prefer URLs (browsers,
            // Finder) get it, then fall back to plain text.
            let provider = NSItemProvider(object: url as NSURL)
            provider.registerObject(text as NSString, visibility: .all)
            return provider
        }

        if let text = textContent {
            return NSItemProvider(object: text as NSString)
        }

        return NSItemProvider()
    }
}

// MARK: - GRDB conformance

extension ClipboardItem: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "clipboardItem"

    /// Store dates as a numeric unix timestamp for fast comparisons & ordering.
    static var databaseDateEncodingStrategy: DatabaseDateEncodingStrategy {
        .timeIntervalSince1970
    }

    static var databaseDateDecodingStrategy: DatabaseDateDecodingStrategy {
        .timeIntervalSince1970
    }

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    enum Columns {
        static let id = Column("id")
        static let contentType = Column("contentType")
        static let textContent = Column("textContent")
        static let imageData = Column("imageData")
        static let urlDomain = Column("urlDomain")
        static let sourceApp = Column("sourceApp")
        static let title = Column("title")
        static let summary = Column("summary")
        static let embedding = Column("embedding")
        static let isPinned = Column("isPinned")
        static let isDuplicate = Column("isDuplicate")
        static let capturedAt = Column("capturedAt")
        static let expiresAt = Column("expiresAt")
        static let metadata = Column("metadata")
    }
}
