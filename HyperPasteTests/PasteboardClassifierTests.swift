import AppKit
import Testing
@testable import HyperPaste

@Suite("PasteboardClassifier")
struct PasteboardClassifierTests {
    private let excludedID = "com.example.passwords"

    private func makeClassifier() -> PasteboardClassifier {
        PasteboardClassifier(excludedBundleIDs: [excludedID])
    }

    // MARK: - Text

    @Test("plain text with no detected patterns classifies as .text")
    func plainText() {
        let snapshot = PasteboardSnapshot(
            types: [.string],
            string: "Hello, world"
        )
        let result = makeClassifier().classify(
            snapshot: snapshot,
            sourceBundleID: "com.example.app"
        )
        guard case let .classified(item) = result else {
            Issue.record("Expected classified, got \(result)")
            return
        }
        #expect(item.kind == .text)
        guard case let .text(raw) = item.payload else {
            Issue.record("Expected .text payload")
            return
        }
        #expect(raw == "Hello, world")
        #expect(item.previewText == "Hello, world")
        #expect(item.searchableText == "hello, world")
    }

    @Test("URL string with link detection classifies as .link")
    func linkDetection() {
        let snapshot = PasteboardSnapshot(
            types: [.string],
            string: "https://example.com",
            detectedKinds: ["links"]
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified, got \(result)")
            return
        }
        #expect(item.kind == .link)
        #expect(item.detectedKinds == ["links"])
    }

    @Test("braced text classifies as .code")
    func codeHeuristicBraces() {
        let snapshot = PasteboardSnapshot(
            types: [.string],
            string: "func add(a: Int, b: Int) -> Int { return a + b }"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified, got \(result)")
            return
        }
        #expect(item.kind == .code)
    }

    @Test("multi-line keyword text classifies as .code")
    func codeHeuristicKeyword() {
        let snapshot = PasteboardSnapshot(
            types: [.string],
            string: "import Foundation\nlet x = 1"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified, got \(result)")
            return
        }
        #expect(item.kind == .code)
    }

    @Test("links take priority over code heuristic")
    func linkBeatsCode() {
        let snapshot = PasteboardSnapshot(
            types: [.string],
            string: "https://example.com/path { with braces }",
            detectedKinds: ["links"]
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified, got \(result)")
            return
        }
        #expect(item.kind == .link)
    }

    // MARK: - Image

    @Test("pasteboard with PNG data classifies as .image")
    func imageClassification() {
        let pngData = TestImage.minimalPNG()
        let snapshot = PasteboardSnapshot(
            types: [.png],
            imageData: pngData
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified, got \(result)")
            return
        }
        #expect(item.kind == .image)
        guard case let .image(data, width, height) = item.payload else {
            Issue.record("Expected .image payload")
            return
        }
        #expect(data == pngData)
        #expect(width > 0)
        #expect(height > 0)
        #expect(item.previewText.contains("×"))
    }

    @Test("image content hash is deterministic")
    func imageHashStable() {
        let pngData = TestImage.minimalPNG()
        let snapshot = PasteboardSnapshot(types: [.png], imageData: pngData)
        let r1 = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        let r2 = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(i1) = r1, case let .classified(i2) = r2 else {
            Issue.record("Expected both classified")
            return
        }
        #expect(i1.contentHash == i2.contentHash)
    }

    @Test("excluded app skip still applies to images")
    func imageExcludedAppSkipped() {
        let snapshot = PasteboardSnapshot(
            types: [.png],
            imageData: TestImage.minimalPNG()
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: excludedID)
        #expect(result == .skipped(.excludedApp(bundleID: excludedID)))
    }

    // MARK: - Files

    @Test("pasteboard with file URLs classifies as .files")
    func filesClassification() {
        let urls = [
            URL(fileURLWithPath: "/tmp/foo.txt"),
            URL(fileURLWithPath: "/tmp/bar.pdf")
        ]
        let snapshot = PasteboardSnapshot(
            types: [.fileURL],
            fileURLs: urls
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified, got \(result)")
            return
        }
        #expect(item.kind == .files)
        guard case let .files(resolvedURLs, names) = item.payload else {
            Issue.record("Expected .files payload")
            return
        }
        #expect(resolvedURLs == urls)
        #expect(names == ["foo.txt", "bar.pdf"])
        #expect(item.previewText.contains("foo.txt"))
        #expect(item.searchableText == "foo.txt bar.pdf")
    }

    @Test("single-file preview shows just the filename")
    func singleFilePreview() {
        let urls = [URL(fileURLWithPath: "/tmp/only.txt")]
        let snapshot = PasteboardSnapshot(types: [.fileURL], fileURLs: urls)
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified")
            return
        }
        #expect(item.previewText == "only.txt")
    }

    @Test("multi-file preview shows count")
    func multiFilePreview() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.txt")
        ]
        let snapshot = PasteboardSnapshot(types: [.fileURL], fileURLs: urls)
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified")
            return
        }
        #expect(item.previewText == "a.txt + 2 more")
    }

    @Test("file URLs take priority over image data on the same pasteboard")
    func filesBeatImage() {
        let snapshot = PasteboardSnapshot(
            types: [.fileURL, .png],
            imageData: TestImage.minimalPNG(),
            fileURLs: [URL(fileURLWithPath: "/tmp/x.png")]
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        guard case let .classified(item) = result else {
            Issue.record("Expected classified")
            return
        }
        #expect(item.kind == .files)
    }

    // MARK: - Skip cases

    @Test("ConcealedType pasteboard is skipped as .concealed")
    func concealedSkipped() {
        let snapshot = PasteboardSnapshot(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
            string: "secret"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        #expect(result == .skipped(.concealed))
    }

    @Test("TransientType pasteboard is skipped as .transient")
    func transientSkipped() {
        let snapshot = PasteboardSnapshot(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.TransientType")],
            string: "ephemeral"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        #expect(result == .skipped(.transient))
    }

    @Test("AutoGeneratedType pasteboard is skipped as .autoGenerated")
    func autoGeneratedSkipped() {
        let snapshot = PasteboardSnapshot(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")],
            string: "generated"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        #expect(result == .skipped(.autoGenerated))
    }

    @Test("is-sensitive pasteboard is skipped as .sensitive")
    func sensitiveSkipped() {
        let snapshot = PasteboardSnapshot(
            types: [.string, NSPasteboard.PasteboardType("com.apple.is-sensitive")],
            string: "private"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        #expect(result == .skipped(.sensitive))
    }

    @Test("excluded bundle ID is skipped")
    func excludedAppSkipped() {
        let snapshot = PasteboardSnapshot(
            types: [.string],
            string: "secret token"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: excludedID)
        #expect(result == .skipped(.excludedApp(bundleID: excludedID)))
    }

    @Test("sensitive type wins over excluded-app check")
    func sensitiveBeatsExcluded() {
        let snapshot = PasteboardSnapshot(
            types: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
            string: "secret"
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: excludedID)
        #expect(result == .skipped(.concealed))
    }

    @Test("empty string is skipped as .noSupportedContent")
    func emptyStringSkipped() {
        let snapshot = PasteboardSnapshot(types: [.string], string: "")
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        #expect(result == .skipped(.noSupportedContent))
    }

    @Test("whitespace-only string is skipped as .noSupportedContent")
    func whitespaceOnlySkipped() {
        let snapshot = PasteboardSnapshot(
            types: [.string],
            string: "   \n\t  "
        )
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        #expect(result == .skipped(.noSupportedContent))
    }

    @Test("nil string with no image/files is skipped as .noSupportedContent")
    func nilStringSkipped() {
        let snapshot = PasteboardSnapshot(types: [.string])
        let result = makeClassifier().classify(snapshot: snapshot, sourceBundleID: nil)
        #expect(result == .skipped(.noSupportedContent))
    }

    @Test("content hash is deterministic for same normalized text")
    func contentHashStable() {
        let s1 = PasteboardSnapshot(types: [.string], string: "Hello")
        let s2 = PasteboardSnapshot(types: [.string], string: "  Hello  ")
        let r1 = makeClassifier().classify(snapshot: s1, sourceBundleID: nil)
        let r2 = makeClassifier().classify(snapshot: s2, sourceBundleID: nil)
        guard case let .classified(i1) = r1, case let .classified(i2) = r2 else {
            Issue.record("Expected both classified")
            return
        }
        #expect(i1.contentHash == i2.contentHash)
    }
}

// MARK: - Fixtures

private enum TestImage {
    /// 2×2 opaque PNG. Tiny but valid; works with NSImage.
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
