import SwiftUI
import UniformTypeIdentifiers

enum HistoryFilter: Hashable, CaseIterable, Sendable {
    case all
    case text
    case code
    case link
    case image
    case files
    case pinned

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .code: return "Code"
        case .link: return "Links"
        case .image: return "Images"
        case .files: return "Files"
        case .pinned: return "Pinned"
        }
    }

    var systemImage: String {
        switch self {
        case .all: return "tray.full"
        case .text: return "text.alignleft"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .link: return "link"
        case .image: return "photo"
        case .files: return "doc.on.doc"
        case .pinned: return "pin.fill"
        }
    }

    func matches(_ item: ClipboardItem) -> Bool {
        switch self {
        case .all: return true
        case .text: return item.kind == .text || item.kind == .color
        case .link: return item.kind == .link
        case .code: return item.kind == .code
        case .image: return item.kind == .image || Self.firstFileIsImage(item)
        case .files: return item.kind == .files && !Self.firstFileIsImage(item)
        case .pinned: return item.pinnedAt != nil
        }
    }

    private static func firstFileIsImage(_ item: ClipboardItem) -> Bool {
        guard item.kind == .files,
              let first = item.fileNames?.first
        else { return false }
        let ext = (first as NSString).pathExtension
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .image)
    }
}
