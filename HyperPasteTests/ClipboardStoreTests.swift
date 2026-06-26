import AppKit
import Foundation
import SwiftData
import Testing
@testable import HyperPaste

@MainActor
@Suite("ClipboardStore")
struct ClipboardStoreTests {
    @Test("consecutive copies of same content collapse to one item")
    func consecutiveCollapse() throws {
        let store = try makeStore()
        let classified = makeTextClassified("Hello")
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        let t1 = Date(timeIntervalSinceReferenceDate: 1_010)

        try store.insert(classified, sourceApp: nil, now: t0)
        try store.insert(classified, sourceApp: nil, now: t1)

        let items = try store.allItems()
        #expect(items.count == 1)
        #expect(items[0].createdAt == t1)
    }

    @Test("different content yields distinct items")
    func distinctItems() throws {
        let store = try makeStore()
        try store.insert(makeTextClassified("Hello"), sourceApp: nil, now: .now)
        try store.insert(makeTextClassified("World"), sourceApp: nil, now: .now)
        let items = try store.allItems()
        #expect(items.count == 2)
    }

    @Test("same content outside dedupe window is a new item")
    func outsideWindow() throws {
        let store = try makeStore()
        store.dedupeWindow = 30
        let classified = makeTextClassified("Hello")
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        let t1 = Date(timeIntervalSinceReferenceDate: 1_100)

        try store.insert(classified, sourceApp: nil, now: t0)
        try store.insert(classified, sourceApp: nil, now: t1)

        let items = try store.allItems()
        #expect(items.count == 2)
    }

    @Test("source app metadata is captured")
    func sourceAppCaptured() throws {
        let store = try makeStore()
        let source = SourceApp(bundleIdentifier: "com.example.app", localizedName: "Example")
        try store.insert(makeTextClassified("Hi"), sourceApp: source, now: .now)
        let items = try store.allItems()
        #expect(items.count == 1)
        #expect(items[0].sourceBundleIdentifier == "com.example.app")
        #expect(items[0].sourceAppName == "Example")
    }

    @Test("groupKey equals contentHash for new inserts")
    func groupKeyEqualsContentHash() throws {
        let store = try makeStore()
        let classified = makeTextClassified("Hello")
        try store.insert(classified, sourceApp: nil, now: .now)
        let items = try store.allItems()
        #expect(items.first?.groupKey == classified.contentHash)
    }

    @Test("link payload is preserved through dedupe collapse")
    func collapsePreservesPayload() throws {
        let store = try makeStore()
        let classified = ClassifiedItem(
            kind: .link,
            payload: .text("https://example.com"),
            previewText: "https://example.com",
            searchableText: "https://example.com",
            contentHash: ContentHasher.sha256Hex("https://example.com"),
            detectedKinds: ["links"]
        )
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        let t1 = Date(timeIntervalSinceReferenceDate: 1_005)

        try store.insert(classified, sourceApp: nil, now: t0)
        try store.insert(classified, sourceApp: nil, now: t1)

        let items = try store.allItems()
        #expect(items.count == 1)
        #expect(items[0].text == "https://example.com")
        #expect(items[0].detectedKinds == ["links"])
        #expect(items[0].kind == .link)
    }


    // MARK: - Image

    @Test("image insert writes attachment file and records dimensions")
    func imageInsertWritesAttachment() throws {
        let tempRoot = try makeTempRoot()
        let store = try makeStore(attachmentRoot: tempRoot)
        let pngData = TestImage.minimalPNG()
        let classified = ClassifiedItem(
            kind: .image,
            payload: .image(pngData: pngData, width: 2, height: 2),
            previewText: "2 × 2",
            searchableText: "",
            contentHash: ContentHasher.sha256Hex(pngData),
            detectedKinds: []
        )
        try store.insert(classified, sourceApp: nil, now: .now)

        let items = try store.allItems()
        #expect(items.count == 1)

        let item = items[0]
        #expect(item.kind == .image)
        let relativePath = try #require(item.imagePath)
        #expect(item.imageWidth == 2)
        #expect(item.imageHeight == 2)

        let onDisk = store.attachmentStore.data(forRelativePath: relativePath)
        #expect(onDisk == pngData)
    }

    // MARK: - Files

    @Test("file insert preserves filenames")
    func filesInsertPreservesNames() throws {
        let store = try makeStore()
        let urls = [
            URL(fileURLWithPath: "/tmp/alpha.txt"),
            URL(fileURLWithPath: "/tmp/beta.pdf")
        ]
        let classified = ClassifiedItem(
            kind: .files,
            payload: .files(urls: urls, names: ["alpha.txt", "beta.pdf"]),
            previewText: "alpha.txt + 1 more",
            searchableText: "alpha.txt beta.pdf",
            contentHash: ContentHasher.sha256Hex(urls.map { $0.path }.joined(separator: "\n")),
            detectedKinds: []
        )
        try store.insert(classified, sourceApp: nil, now: .now)
        let items = try store.allItems()
        #expect(items.count == 1)
        #expect(items[0].fileNames == ["alpha.txt", "beta.pdf"])
        #expect(items[0].kind == .files)
    }

    @Test("multi-file paste deduplicates overlapping URLs")
    func multiFilePasteDeduplicatesOverlappingURLs() throws {
        let root = try makeTempRoot()
        let alpha = try makeTempFile(named: "alpha.txt", in: root)
        let beta = try makeTempFile(named: "beta.txt", in: root)
        let gamma = try makeTempFile(named: "gamma.txt", in: root)
        let first = try makeFileItem(urls: [alpha, beta])
        let second = try makeFileItem(urls: [beta, gamma, alpha])

        let didWrite = PasteCoordinator().writeBackFiles([first, second])

        #expect(didWrite)
        let written = readFileURLsFromPasteboard()
        #expect(written == [alpha, beta, gamma].map(\.standardizedFileURL))
    }

    @Test("multi-file paste preserves first-seen URL order")
    func multiFilePastePreservesFirstSeenURLOrder() throws {
        let root = try makeTempRoot()
        let firstURL = try makeTempFile(named: "first.txt", in: root)
        let secondURL = try makeTempFile(named: "second.txt", in: root)
        let thirdURL = try makeTempFile(named: "third.txt", in: root)
        let first = try makeFileItem(urls: [secondURL, firstURL])
        let second = try makeFileItem(urls: [thirdURL, secondURL])

        let didWrite = PasteCoordinator().writeBackFiles([first, second])

        #expect(didWrite)
        let written = readFileURLsFromPasteboard()
        #expect(written == [secondURL, firstURL, thirdURL].map(\.standardizedFileURL))
    }

    @Test("multi-text paste joins items with newlines")
    func multiTextPasteJoinsItemsWithNewlines() {
        let items = [
            makeTextItem("Alpha", kind: .text),
            makeTextItem("let beta = true", kind: .code),
            makeTextItem("https://example.com", kind: .link)
        ]

        let didWrite = PasteCoordinator().writeBackSelected(items)

        #expect(didWrite)
        #expect(NSPasteboard.general.string(forType: .string) == "Alpha\nlet beta = true\nhttps://example.com")
    }

    @Test("mixed bulk paste is rejected")
    func mixedBulkPasteIsRejected() throws {
        let root = try makeTempRoot()
        let fileURL = try makeTempFile(named: "alpha.txt", in: root)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Existing", forType: .string)

        let didWrite = PasteCoordinator().writeBackSelected([
            makeTextItem("Alpha"),
            try makeFileItem(urls: [fileURL])
        ])

        #expect(!didWrite)
        #expect(NSPasteboard.general.string(forType: .string) == "Existing")
    }

    // MARK: - Clear

    @Test("clearAll removes all records and image attachments")
    func clearAllRemovesRecordsAndAttachments() throws {
        let tempRoot = try makeTempRoot()
        let store = try makeStore(attachmentRoot: tempRoot)

        try store.insert(makeTextClassified("Hello"), sourceApp: nil, now: .now)

        let pngData = TestImage.minimalPNG()
        let imageClassified = ClassifiedItem(
            kind: .image,
            payload: .image(pngData: pngData, width: 2, height: 2),
            previewText: "2 × 2",
            searchableText: "",
            contentHash: ContentHasher.sha256Hex(pngData),
            detectedKinds: []
        )
        try store.insert(imageClassified, sourceApp: nil, now: .now)

        let before = try store.allItems()
        #expect(before.count == 2)
        let imagePath = try #require(before.first(where: { $0.kind == .image })?.imagePath)
        let imageURL = tempRoot.appendingPathComponent(imagePath)
        #expect(FileManager.default.fileExists(atPath: imageURL.path))

        try store.clearAll()

        let after = try store.allItems()
        #expect(after.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))
    }

    @Test("clearAll is a no-op when history is already empty")
    func clearAllNoOpWhenEmpty() throws {
        let store = try makeStore()
        try store.clearAll()
        #expect(try store.allItems().isEmpty)
    }

    @Test("delete removes only the targeted record and leaves siblings intact")
    func deleteRemovesOnlyTargetedRecord() throws {
        let store = try makeStore()
        try store.insert(makeTextClassified("Hello"), sourceApp: nil, now: .now)
        try store.insert(makeTextClassified("World"), sourceApp: nil, now: .now)

        let before = try store.allItems()
        #expect(before.count == 2)
        let target = try #require(before.first(where: { $0.text == "Hello" }))

        try store.delete(target)

        let after = try store.allItems()
        #expect(after.count == 1)
        #expect(after.first?.text == "World")
    }

    @Test("delete removes associated image attachment file")
    func deleteRemovesImageAttachmentFile() throws {
        let tempRoot = try makeTempRoot()
        let store = try makeStore(attachmentRoot: tempRoot)
        let pngData = TestImage.minimalPNG()
        let classified = ClassifiedItem(
            kind: .image,
            payload: .image(pngData: pngData, width: 2, height: 2),
            previewText: "2 × 2",
            searchableText: "",
            contentHash: ContentHasher.sha256Hex(pngData),
            detectedKinds: []
        )
        try store.insert(classified, sourceApp: nil, now: .now)
        let item = try #require(try store.allItems().first)
        let imagePath = try #require(item.imagePath)
        let imageURL = tempRoot.appendingPathComponent(imagePath)
        #expect(FileManager.default.fileExists(atPath: imageURL.path))

        try store.delete(item)

        #expect(try store.allItems().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))
    }

    @Test("delete on a files item leaves the original file on disk")
    func deleteFilesItemPreservesOriginalFile() throws {
        let root = try makeTempRoot()
        let fileURL = try makeTempFile(named: "keep.txt", in: root)
        let item = try makeFileItem(urls: [fileURL])
        let store = try makeStore()
        store.container.mainContext.insert(item)
        try store.container.mainContext.save()

        try store.delete(item)

        #expect(try store.allItems().isEmpty)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("bulk delete removes selected records and image attachments")
    func bulkDeleteRemovesRecordsAndImageAttachments() throws {
        let tempRoot = try makeTempRoot()
        let store = try makeStore(attachmentRoot: tempRoot)
        try store.insert(makeTextClassified("Keep"), sourceApp: nil, now: .now)
        try store.insert(makeTextClassified("Remove"), sourceApp: nil, now: .now)
        let pngData = TestImage.minimalPNG()
        try store.insert(
            ClassifiedItem(
                kind: .image,
                payload: .image(pngData: pngData, width: 2, height: 2),
                previewText: "2 × 2",
                searchableText: "",
                contentHash: ContentHasher.sha256Hex(pngData),
                detectedKinds: []
            ),
            sourceApp: nil,
            now: .now
        )

        let before = try store.allItems()
        let textItem = try #require(before.first(where: { $0.text == "Remove" }))
        let imageItem = try #require(before.first(where: { $0.kind == .image }))
        let imagePath = try #require(imageItem.imagePath)
        let imageURL = tempRoot.appendingPathComponent(imagePath)

        try store.delete([textItem, imageItem])

        let after = try store.allItems()
        #expect(after.count == 1)
        #expect(after.first?.text == "Keep")
        #expect(!FileManager.default.fileExists(atPath: imageURL.path))
    }

    // MARK: - Pinning

    @Test("setPinned marks an item as pinned and unpinned without reordering")
    func setPinnedTogglesMetadataWithoutReordering() throws {
        let store = try makeStore()
        let t0 = Date(timeIntervalSinceReferenceDate: 1_000)
        let t1 = Date(timeIntervalSinceReferenceDate: 1_010)
        try store.insert(makeTextClassified("Older"), sourceApp: nil, now: t0)
        try store.insert(makeTextClassified("Newer"), sourceApp: nil, now: t1)

        let older = try #require(try store.allItems().first(where: { $0.text == "Older" }))
        let originalCreatedAt = older.createdAt
        let pinTime = Date(timeIntervalSinceReferenceDate: 2_000)

        try store.setPinned(older, pinned: true, now: pinTime)
        #expect(older.pinnedAt == pinTime)
        #expect(older.createdAt == originalCreatedAt)

        let afterPin = try store.allItems()
        #expect(afterPin.map(\.text) == ["Newer", "Older"])

        try store.setPinned(older, pinned: false)
        #expect(older.pinnedAt == nil)
        #expect(older.createdAt == originalCreatedAt)

        let afterUnpin = try store.allItems()
        #expect(afterUnpin.map(\.text) == ["Newer", "Older"])
    }

    @Test("setPinned is a no-op when the desired state already matches")
    func setPinnedNoOpWhenAlreadyMatching() throws {
        let store = try makeStore()
        try store.insert(makeTextClassified("Only"), sourceApp: nil, now: .now)
        let item = try #require(try store.allItems().first)

        try store.setPinned(item, pinned: false)
        #expect(item.pinnedAt == nil)

        let pinTime = Date(timeIntervalSinceReferenceDate: 3_000)
        try store.setPinned(item, pinned: true, now: pinTime)
        #expect(item.pinnedAt == pinTime)

        try store.setPinned(item, pinned: true, now: Date(timeIntervalSinceReferenceDate: 4_000))
        #expect(item.pinnedAt == pinTime)
    }

    // MARK: - Availability

    @Test("pruneUnavailableFileItems removes file items whose bookmarks no longer resolve")
    func pruneUnavailableFileItemsRemovesUnresolvableFileItems() throws {
        let store = try makeStore()
        let bogusBookmark = Data([0, 1, 2, 3, 4])
        let item = ClipboardItem(
            createdAt: .now,
            kind: .files,
            contentHash: "missing-file",
            groupKey: "missing-file",
            fileBookmarks: [bogusBookmark],
            fileNames: ["gone.txt"],
            previewText: "gone.txt",
            searchableText: "gone.txt",
            detectedKinds: [],
            sourceBundleIdentifier: nil,
            sourceAppName: nil
        )
        store.container.mainContext.insert(item)
        try store.container.mainContext.save()

        try store.pruneUnavailableFileItems()

        #expect(try store.allItems().isEmpty)
    }

    @Test("pruneUnavailableFileItems removes file items whose files were permanently deleted")
    func pruneUnavailableFileItemsRemovesDeletedFiles() throws {
        let store = try makeStore()
        let root = try makeTempRoot()
        let fileURL = try makeTempFile(named: "delete-me.txt", in: root)
        let item = try makeFileItem(urls: [fileURL])
        store.container.mainContext.insert(item)
        try store.container.mainContext.save()

        try FileManager.default.removeItem(at: fileURL)
        try store.pruneUnavailableFileItems()

        #expect(try store.allItems().isEmpty)
    }

    @Test("pruneUnavailableFileItems removes file items whose files were moved to Trash")
    func pruneUnavailableFileItemsRemovesTrashedFiles() throws {
        let store = try makeStore()
        let root = try makeTempRoot()
        let fileURL = try makeTempFile(named: "trash-me.txt", in: root)
        let item = try makeFileItem(urls: [fileURL])
        store.container.mainContext.insert(item)
        try store.container.mainContext.save()

        var trashedURL: NSURL?
        try FileManager.default.trashItem(at: fileURL, resultingItemURL: &trashedURL)
        defer {
            if let url = trashedURL as URL? {
                try? FileManager.default.removeItem(at: url)
            }
        }

        try store.pruneUnavailableFileItems()

        #expect(try store.allItems().isEmpty)
    }

    @Test("pruneUnavailableFileItems leaves non-file items unchanged")
    func pruneUnavailableFileItemsLeavesNonFileItemsUnchanged() throws {
        let store = try makeStore()
        try store.insert(makeTextClassified("Keep me"), sourceApp: nil, now: .now)

        try store.pruneUnavailableFileItems()

        let items = try store.allItems()
        #expect(items.count == 1)
        #expect(items.first?.text == "Keep me")
    }

    // MARK: - Fixtures

    private func makeStore(attachmentRoot: URL? = nil) throws -> ClipboardStore {
        let root = try attachmentRoot ?? makeTempRoot()
        let attachmentStore = try AttachmentStore(rootURL: root)
        return try ClipboardStore(inMemory: true, attachmentStore: attachmentStore)
    }

    private func makeTempRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hyperpaste-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeTempFile(named name: String, in root: URL) throws -> URL {
        let url = root.appendingPathComponent(name)
        try name.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeFileItem(urls: [URL]) throws -> ClipboardItem {
        let bookmarks = try urls.map { try $0.bookmarkData(options: .withSecurityScope) }
        return ClipboardItem(
            createdAt: .now,
            kind: .files,
            contentHash: ContentHasher.sha256Hex(urls.map(\.path).joined(separator: "\n")),
            groupKey: UUID().uuidString,
            fileBookmarks: bookmarks,
            fileNames: urls.map(\.lastPathComponent),
            previewText: urls.first?.lastPathComponent ?? "Files",
            searchableText: urls.map(\.lastPathComponent).joined(separator: " ").lowercased(),
            detectedKinds: [],
            sourceBundleIdentifier: nil,
            sourceAppName: nil
        )
    }

    private func makeTextItem(_ text: String, kind: ItemKind = .text) -> ClipboardItem {
        ClipboardItem(
            createdAt: .now,
            kind: kind,
            contentHash: ContentHasher.sha256Hex(text),
            groupKey: UUID().uuidString,
            text: text,
            previewText: text,
            searchableText: text.lowercased(),
            detectedKinds: [],
            sourceBundleIdentifier: nil,
            sourceAppName: nil
        )
    }

    private func readFileURLsFromPasteboard() -> [URL] {
        let objects = NSPasteboard.general.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) ?? []
        return objects.compactMap { object in
            if let url = object as? URL {
                return url.standardizedFileURL
            }
            return (object as? NSURL)?.filePathURL?.standardizedFileURL
        }
    }

    private func makeTextClassified(_ text: String) -> ClassifiedItem {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ClassifiedItem(
            kind: .text,
            payload: .text(text),
            previewText: text,
            searchableText: text.lowercased(),
            contentHash: ContentHasher.sha256Hex(normalized),
            detectedKinds: []
        )
    }
}

private enum TestImage {
    static func minimalPNG() -> Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])!
    }
}
