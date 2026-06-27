import Foundation
import Testing
@testable import HyperPaste

@Suite("HistoryFilter")
struct HistoryFilterTests {
    @Test("All matches every kind")
    func allMatchesEveryKind() {
        for kind in ItemKind.allCases {
            #expect(HistoryFilter.all.matches(makeItem(kind: kind)))
        }
    }

    @Test("non-image filters match only their exact kind")
    func nonImageFiltersMatchExactKind() {
        #expect(HistoryFilter.text.matches(makeItem(kind: .text)))
        #expect(HistoryFilter.text.matches(makeItem(kind: .color)))
        #expect(!HistoryFilter.text.matches(makeItem(kind: .link)))
        #expect(!HistoryFilter.text.matches(makeItem(kind: .code)))
        #expect(!HistoryFilter.text.matches(makeItem(kind: .image)))
        #expect(!HistoryFilter.text.matches(makeItem(kind: .files, fileNames: ["a.png"])))

        #expect(HistoryFilter.link.matches(makeItem(kind: .link)))
        #expect(!HistoryFilter.link.matches(makeItem(kind: .text)))

        #expect(HistoryFilter.code.matches(makeItem(kind: .code)))
        #expect(!HistoryFilter.code.matches(makeItem(kind: .files, fileNames: ["x.swift"])))
    }

    @Test("Files matches non-image files but excludes image files")
    func filesExcludesImageFiles() {
        #expect(HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["doc.pdf"])))
        #expect(HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["notes.md"])))
        #expect(HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["archive.zip"])))
        #expect(HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["installer.dmg"])))
        #expect(HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["MyFolder"])))
        #expect(HistoryFilter.files.matches(makeItem(kind: .files, fileNames: nil)))

        #expect(!HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["photo.png"])))
        #expect(!HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["photo.heic"])))
        #expect(!HistoryFilter.files.matches(makeItem(kind: .files, fileNames: ["motion.gif"])))

        #expect(!HistoryFilter.files.matches(makeItem(kind: .image)))
        #expect(!HistoryFilter.files.matches(makeItem(kind: .text)))
    }

    @Test("filter ordering matches All, Text, Code, Links, Images, Files, Pinned")
    func filterOrdering() {
        #expect(HistoryFilter.allCases == [.all, .text, .code, .link, .image, .files, .pinned])
    }

    @Test("Pinned matches only items with a pinnedAt timestamp")
    func pinnedMatchesOnlyPinned() {
        let pinnedText = makeItem(kind: .text, pinnedAt: .now)
        let unpinnedText = makeItem(kind: .text)
        let pinnedImage = makeItem(kind: .image, pinnedAt: .now)
        let pinnedFile = makeItem(kind: .files, fileNames: ["doc.pdf"], pinnedAt: .now)

        #expect(HistoryFilter.pinned.matches(pinnedText))
        #expect(HistoryFilter.pinned.matches(pinnedImage))
        #expect(HistoryFilter.pinned.matches(pinnedFile))
        #expect(!HistoryFilter.pinned.matches(unpinnedText))
        #expect(!HistoryFilter.pinned.matches(makeItem(kind: .image)))
        #expect(!HistoryFilter.pinned.matches(makeItem(kind: .files, fileNames: ["doc.pdf"])))
    }

    @Test("Pinned items still match their kind-based filter")
    func pinnedItemsMatchKindFilters() {
        let pinnedText = makeItem(kind: .text, pinnedAt: .now)
        let pinnedImageFile = makeItem(kind: .files, fileNames: ["photo.png"], pinnedAt: .now)
        let pinnedDocFile = makeItem(kind: .files, fileNames: ["notes.md"], pinnedAt: .now)

        #expect(HistoryFilter.text.matches(pinnedText))
        #expect(HistoryFilter.all.matches(pinnedText))
        #expect(HistoryFilter.image.matches(pinnedImageFile))
        #expect(HistoryFilter.files.matches(pinnedDocFile))
    }

    @Test("Images matches true image clipboard payloads")
    func imagesMatchesImagePayload() {
        #expect(HistoryFilter.image.matches(makeItem(kind: .image)))
    }

    @Test("Images matches files whose first filename is an image type")
    func imagesMatchesImageFiles() {
        #expect(HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["screenshot.png"])))
        #expect(HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["photo.JPG"])))
        #expect(HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["photo.heic"])))
        #expect(HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["icon.tiff"])))
        #expect(HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["motion.gif"])))
        #expect(HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["vector.svg"])))
    }

    @Test("Images does not match files whose first filename is not an image type")
    func imagesIgnoresNonImageFiles() {
        #expect(!HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["report.pdf"])))
        #expect(!HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["notes.txt"])))
        #expect(!HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["archive.zip"])))
        #expect(!HistoryFilter.image.matches(makeItem(kind: .files, fileNames: ["binary"])))
        #expect(!HistoryFilter.image.matches(makeItem(kind: .files, fileNames: nil)))
        #expect(!HistoryFilter.image.matches(makeItem(kind: .files, fileNames: [])))
    }

    @Test("Images qualification only inspects the first filename")
    func imagesQualifiesByFirstFilename() {
        let firstIsImage = makeItem(kind: .files, fileNames: ["screenshot.png", "notes.txt"])
        let firstIsText = makeItem(kind: .files, fileNames: ["notes.txt", "screenshot.png"])
        #expect(HistoryFilter.image.matches(firstIsImage))
        #expect(!HistoryFilter.image.matches(firstIsText))
    }

    // MARK: - Fixtures

    private func makeItem(
        kind: ItemKind,
        fileNames: [String]? = nil,
        pinnedAt: Date? = nil
    ) -> ClipboardItem {
        ClipboardItem(
            createdAt: .now,
            kind: kind,
            contentHash: "test",
            groupKey: "test",
            fileNames: fileNames,
            previewText: "preview",
            searchableText: "preview",
            detectedKinds: [],
            sourceBundleIdentifier: nil,
            sourceAppName: nil,
            pinnedAt: pinnedAt
        )
    }
}
