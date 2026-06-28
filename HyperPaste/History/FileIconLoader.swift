import AppKit
import UniformTypeIdentifiers

@MainActor
enum FileIconLoader {
    static func icon(forPath path: String, size: CGFloat = 56) -> NSImage {
        icon(for: URL(fileURLWithPath: path), size: size)
    }

    static func icon(for url: URL, size: CGFloat = 56) -> NSImage {
        if isApplication(at: url) {
            return sizedIcon(NSWorkspace.shared.icon(forFile: url.path), size: size)
        }

        if let typeIcon = standaloneTypeIcon(for: url, size: size) {
            return typeIcon
        }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return sizedIcon(icon, size: size)
    }

    private static func isApplication(at url: URL) -> Bool {
        url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame
    }

    private static func standaloneTypeIcon(for url: URL, size: CGFloat) -> NSImage? {
        guard let contentType = contentType(for: url),
              shouldUseStandaloneTypeIcon(contentType, url: url)
        else { return nil }

        let icon = NSWorkspace.shared.icon(for: contentType)
        return sizedIcon(icon, size: size)
    }

    private static func contentType(for url: URL) -> UTType? {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type
        }

        let ext = url.pathExtension
        guard !ext.isEmpty else { return nil }
        return UTType(filenameExtension: ext)
    }

    private static func shouldUseStandaloneTypeIcon(_ contentType: UTType, url: URL) -> Bool {
        if contentType.conforms(to: .folder) {
            return false
        }

        if contentType.conforms(to: .archive)
            || contentType.conforms(to: .diskImage)
            || contentType.conforms(to: .pdf)
            || contentType.conforms(to: .audio)
            || contentType.conforms(to: .movie)
            || contentType.conforms(to: .sourceCode)
            || contentType.conforms(to: .json)
            || isMarkdown(url)
            || isStylesheet(url) {
            return true
        }

        return false
    }

    private static func isMarkdown(_ url: URL) -> Bool {
        ["md", "markdown"].contains(url.pathExtension.lowercased())
    }

    private static func isStylesheet(_ url: URL) -> Bool {
        ["css", "scss", "sass"].contains(url.pathExtension.lowercased())
    }

    private static func sizedIcon(_ image: NSImage, size: CGFloat) -> NSImage {
        image.size = NSSize(width: size, height: size)
        return image
    }
}
