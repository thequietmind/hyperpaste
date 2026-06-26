import AppKit

enum ImageDimensions {
    static func read(from data: Data) -> (width: Int, height: Int)? {
        guard let image = NSImage(data: data) else { return nil }
        if let rep = image.representations.first as? NSBitmapImageRep {
            return (rep.pixelsWide, rep.pixelsHigh)
        }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        return (Int(size.width), Int(size.height))
    }

    static func normalizeToPNG(_ data: Data) -> (pngData: Data, width: Int, height: Int)? {
        guard let image = NSImage(data: data) else { return nil }
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return (png, bitmap.pixelsWide, bitmap.pixelsHigh)
    }
}
