import AppKit

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    private var imagePayloadCache: [UUID: NSImage] = [:]
    private var fileURLCache: [UUID: NSImage] = [:]
    private let maxSide: CGFloat = 56

    private init() {}

    func thumbnail(for item: ClipboardItem, attachmentStore: AttachmentStore) -> NSImage? {
        if let cached = imagePayloadCache[item.id] {
            return cached
        }
        guard let path = item.imagePath,
              let data = attachmentStore.data(forRelativePath: path),
              let original = NSImage(data: data)
        else { return nil }
        let resized = Self.resize(original, maxSide: maxSide)
        imagePayloadCache[item.id] = resized
        return resized
    }

    func fileThumbnail(forID id: UUID) -> NSImage? {
        fileURLCache[id]
    }

    func setFileThumbnail(_ image: NSImage, forID id: UUID) {
        fileURLCache[id] = image
    }

    func evict(id: UUID) {
        imagePayloadCache.removeValue(forKey: id)
        fileURLCache.removeValue(forKey: id)
    }

    private static func resize(_ image: NSImage, maxSide: CGFloat) -> NSImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(maxSide / size.width, maxSide / size.height, 1)
        let targetSize = NSSize(width: size.width * scale, height: size.height * scale)
        let resized = NSImage(size: targetSize)
        resized.lockFocus()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        resized.unlockFocus()
        return resized
    }
}
