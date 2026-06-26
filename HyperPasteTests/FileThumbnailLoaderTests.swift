import AppKit
import Foundation
import Testing
@testable import HyperPaste

@Suite("FileThumbnailLoader")
struct FileThumbnailLoaderTests {
    @Test("recognizes PNG file as image")
    func recognizesPNG() throws {
        let url = try makeTempPNG()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileThumbnailLoader.isImageFile(at: url))
    }

    @Test("recognizes JPEG file as image")
    func recognizesJPEG() throws {
        let url = try makeTempJPEG()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(FileThumbnailLoader.isImageFile(at: url))
    }

    @Test("does not treat plain text as image")
    func ignoresPlainText() throws {
        let url = try makeTempText()
        defer { try? FileManager.default.removeItem(at: url) }
        #expect(!FileThumbnailLoader.isImageFile(at: url))
    }

    // MARK: - Fixtures

    private func makeTempPNG() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hyperpaste-thumb-\(UUID().uuidString).png")
        try minimalPNG().write(to: url)
        return url
    }

    private func makeTempJPEG() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hyperpaste-thumb-\(UUID().uuidString).jpg")
        try minimalJPEG().write(to: url)
        return url
    }

    private func makeTempText() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("hyperpaste-thumb-\(UUID().uuidString).txt")
        try "hello".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func minimalPNG() -> Data {
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
        return bitmap.representation(using: .png, properties: [:])!
    }

    private func minimalJPEG() -> Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 2,
            pixelsHigh: 2,
            bitsPerSample: 8,
            samplesPerPixel: 3,
            hasAlpha: false,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return bitmap.representation(using: .jpeg, properties: [:])!
    }
}
