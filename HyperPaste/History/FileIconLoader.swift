import AppKit

@MainActor
enum FileIconLoader {
    static func icon(forPath path: String, size: CGFloat = 56) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }
}
