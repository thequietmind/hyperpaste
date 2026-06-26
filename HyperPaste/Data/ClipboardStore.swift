import Foundation
import SwiftData

@MainActor
final class ClipboardStore {
    let container: ModelContainer
    let attachmentStore: AttachmentStore
    var dedupeWindow: TimeInterval = 30

    init(
        inMemory: Bool = false,
        attachmentStore: AttachmentStore? = nil
    ) throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        self.container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: config
        )
        if let attachmentStore {
            self.attachmentStore = attachmentStore
        } else {
            self.attachmentStore = try AttachmentStore()
        }
    }

    func insert(
        _ classified: ClassifiedItem,
        sourceApp: SourceApp?,
        now: Date = .now
    ) throws {
        let context = container.mainContext
        let cutoff = now.addingTimeInterval(-dedupeWindow)
        let hash = classified.contentHash

        var descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { item in
                item.contentHash == hash && item.createdAt >= cutoff
            },
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            existing.createdAt = now
            try context.save()
            return
        }

        let id = UUID()
        let (text, imagePath, imageWidth, imageHeight, fileBookmarks, fileNames) =
            try unpackPayload(classified.payload, id: id)

        let item = ClipboardItem(
            id: id,
            createdAt: now,
            kind: classified.kind,
            contentHash: classified.contentHash,
            groupKey: classified.contentHash,
            text: text,
            imagePath: imagePath,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            fileBookmarks: fileBookmarks,
            fileNames: fileNames,
            previewText: classified.previewText,
            searchableText: classified.searchableText,
            detectedKinds: classified.detectedKinds,
            sourceBundleIdentifier: sourceApp?.bundleIdentifier,
            sourceAppName: sourceApp?.localizedName
        )
        context.insert(item)
        try context.save()
    }

    func allItems(sortedByCreatedAt order: SortOrder = .reverse) throws -> [ClipboardItem] {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\ClipboardItem.createdAt, order: order)]
        )
        return try container.mainContext.fetch(descriptor)
    }

    func pruneUnavailableFileItems() throws {
        let items = try container.mainContext.fetch(FetchDescriptor<ClipboardItem>())
        let unavailableItems = items.filter { item in
            guard item.kind == .files else { return false }
            guard let bookmarks = item.fileBookmarks else { return true }
            return !FileAvailability.isAvailable(bookmarks: bookmarks)
        }
        try delete(unavailableItems)
    }

    func clearAll() throws {
        let context = container.mainContext
        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        for item in items {
            if let imagePath = item.imagePath {
                attachmentStore.delete(relativePath: imagePath)
            }
            context.delete(item)
        }
        try context.save()
    }

    func delete(_ item: ClipboardItem) throws {
        try delete([item])
    }

    func delete(_ items: [ClipboardItem]) throws {
        guard !items.isEmpty else { return }
        let context = container.mainContext
        for item in items {
            if let imagePath = item.imagePath {
                attachmentStore.delete(relativePath: imagePath)
            }
            context.delete(item)
        }
        try context.save()
    }

    func setPinned(_ item: ClipboardItem, pinned: Bool, now: Date = .now) throws {
        let isPinned = item.pinnedAt != nil
        guard isPinned != pinned else { return }
        item.pinnedAt = pinned ? now : nil
        try container.mainContext.save()
    }

    // MARK: - Payload unpacking

    private func unpackPayload(
        _ payload: ClassifiedItem.Payload,
        id: UUID
    ) throws -> (
        text: String?,
        imagePath: String?,
        imageWidth: Int?,
        imageHeight: Int?,
        fileBookmarks: [Data]?,
        fileNames: [String]?
    ) {
        switch payload {
        case .text(let raw):
            return (raw, nil, nil, nil, nil, nil)
        case .image(let pngData, let width, let height):
            let path = try attachmentStore.write(pngData: pngData, id: id)
            return (nil, path, width, height, nil, nil)
        case .files(let urls, let names):
            let bookmarks = urls.compactMap { try? $0.bookmarkData(options: .withSecurityScope) }
            return (nil, nil, nil, nil, bookmarks, names)
        }
    }
}
