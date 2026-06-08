import Foundation

/// A selectable node in the left-hand category tree.
///
/// `all` and `pinned` are virtual buckets, the content types map onto the
/// `contentType` column, and `domain` is a leaf under the URL group.
enum SidebarSelection: Hashable, Identifiable {
    case all
    case pinned
    case type(ContentType)
    case domain(String)

    var id: String {
        switch self {
        case .all: return "all"
        case .pinned: return "pinned"
        case .type(let t): return "type.\(t.rawValue)"
        case .domain(let d): return "domain.\(d)"
        }
    }

    var title: String {
        switch self {
        case .all: return "All"
        case .pinned: return "Pinned"
        case .type(let t): return t.displayName
        case .domain(let d): return d
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "tray.full"
        case .pinned: return "pin.fill"
        case .type(let t): return t.systemImage
        case .domain: return "globe"
        }
    }
}

/// Ordering options exposed in the toolbar.
enum ItemSortOrder: String, CaseIterable, Identifiable {
    case dateNewest
    case dateOldest
    case type
    case alphabetical

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        case .type: return "By Type"
        case .alphabetical: return "Alphabetical"
        }
    }
}
