import AppKit

@MainActor
struct PasteCoordinator {
    func writeBack(
        _ item: ClipboardItem,
        plainText: Bool,
        attachmentStore: AttachmentStore?
    ) -> Bool {
        let pasteboard = NSPasteboard.general

        switch item.kind {
        case .text, .link, .code:
            guard let text = item.text else { return false }
            _ = plainText
            pasteboard.clearContents()
            return pasteboard.setString(text, forType: .string)
        case .image:
            guard let path = item.imagePath,
                  let data = attachmentStore?.data(forRelativePath: path)
            else { return false }
            pasteboard.clearContents()
            return pasteboard.setData(data, forType: .png)
        case .files:
            guard let bookmarks = item.fileBookmarks else { return false }
            let urls: [URL] = bookmarks.compactMap { Self.resolveForAvailability(bookmark: $0) }
            guard !urls.isEmpty else { return false }
            pasteboard.clearContents()
            return pasteboard.writeObjects(urls as [NSURL])
        }
    }

    func writeBackSelected(_ items: [ClipboardItem]) -> Bool {
        guard !items.isEmpty else { return false }
        if items.allSatisfy({ $0.kind == .files }) {
            return writeBackFiles(items)
        }
        if items.allSatisfy({ Self.isTextLike($0.kind) }) {
            return writeBackText(items)
        }
        return false
    }

    func writeBackText(_ items: [ClipboardItem]) -> Bool {
        let textValues = items.compactMap(\.text)
        guard textValues.count == items.count else { return false }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(textValues.joined(separator: "\n"), forType: .string)
    }

    func writeBackFiles(_ items: [ClipboardItem]) -> Bool {
        var seenURLs: Set<URL> = []
        var urls: [URL] = []

        for item in items where item.kind == .files {
            guard let bookmarks = item.fileBookmarks else { continue }
            for bookmark in bookmarks {
                guard let url = Self.resolveForAvailability(bookmark: bookmark) else { continue }
                let key = url.standardizedFileURL
                if seenURLs.insert(key).inserted {
                    urls.append(url)
                }
            }
        }
        guard !urls.isEmpty else { return false }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.writeObjects(urls as [NSURL])
    }

    private static func isTextLike(_ kind: ItemKind) -> Bool {
        switch kind {
        case .text, .link, .code:
            return true
        case .image, .files:
            return false
        }
    }

}

@MainActor
enum FileAvailability {
    static func isAvailable(bookmarks: [Data]) -> Bool {
        guard !bookmarks.isEmpty else { return false }
        for blob in bookmarks {
            if PasteCoordinator.resolveForAvailability(bookmark: blob) == nil {
                return false
            }
        }
        return true
    }
}

extension PasteCoordinator {
    static func resolveForAvailability(bookmark: Data) -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if !FileManager.default.fileExists(atPath: url.path) {
            return nil
        }

        if isTrashed(url) {
            return nil
        }

        return url
    }

    private static func isTrashed(_ url: URL) -> Bool {
        let standardizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let path = standardizedURL.path
        for trashURL in FileManager.default.urls(for: .trashDirectory, in: .allDomainsMask) {
            let trashPath = trashURL.standardizedFileURL.resolvingSymlinksInPath().path
            if path == trashPath || path.hasPrefix(trashPath + "/") {
                return true
            }
        }
        let pathComponents = standardizedURL.pathComponents
        return pathComponents.contains(".Trash") || pathComponents.contains(".Trashes")
    }
}
