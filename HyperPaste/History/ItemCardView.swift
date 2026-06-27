import SwiftUI
import AppKit

struct ItemCardView: View {
    let item: ClipboardItem
    let attachmentStore: AttachmentStore
    let isSelected: Bool
    let onRequestDelete: () -> Void
    let onRequestTogglePin: () -> Void

    @State private var thumbnail: NSImage?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private var isPinned: Bool { item.pinnedAt != nil }
    private var pinMenuTitle: LocalizedStringKey { isPinned ? "Unpin" : "Pin" }
    private var parsedColor: ParsedColor? {
        guard item.kind == .color, let text = item.text else { return nil }
        return ColorParser.parse(text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            leadingVisual

            VStack(alignment: .leading, spacing: 4) {
                title
                metadataRow
            }

            Spacer(minLength: 12)

            if isPinned {
                Image(systemName: "star.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(pinColor)
                    .accessibilityLabel("Pinned")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(minHeight: 66)
        .background {
            Capsule(style: .continuous)
                .fill(rowFill)
        }
        .contentShape(Capsule(style: .continuous))
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isSelected)
        .task(id: item.id) {
            thumbnail = await loadThumbnail()
        }
        .contextMenu {
            Button(pinMenuTitle) {
                onRequestTogglePin()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onRequestDelete()
            }
        }
    }

    private var rowFill: Color {
        isSelected ? selectedRowFill : .clear
    }

    private var selectedRowFill: Color {
        colorScheme == .dark
            ? Color(red: 0.18, green: 0.17, blue: 0.36)
            : Color(red: 0.90, green: 0.89, blue: 1.00)
    }

    private var pinColor: Color {
        colorScheme == .dark
            ? Color(red: 0.55, green: 0.51, blue: 1.00)
            : Color(red: 0.39, green: 0.35, blue: 0.92)
    }

    // MARK: - Badge

    @ViewBuilder
    private var leadingVisual: some View {
        if item.kind == .color, let parsedColor {
            colorBadge(for: parsedColor)
        } else if let thumbnail {
            thumbnailBadge(thumbnail)
        } else {
            glyphBadge
        }
    }

    private func colorBadge(for color: ParsedColor) -> some View {
        ZStack {
            if color.alpha < 1 {
                Checkerboard(size: 4)
            }
            Circle()
                .fill(swiftUIColor(color))
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private func thumbnailBadge(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityHidden(true)
    }

    private var glyphBadge: some View {
        ZStack {
            Circle()
                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.55))
            Image(systemName: item.kind.symbolName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 40, height: 40)
    }

    private func loadThumbnail() async -> NSImage? {
        switch item.kind {
        case .image:
            return ThumbnailCache.shared.thumbnail(for: item, attachmentStore: attachmentStore)
        case .files:
            return await loadFileThumbnail()
        case .text, .link, .code, .color:
            return nil
        }
    }

    private func loadFileThumbnail() async -> NSImage? {
        guard let bookmarks = item.fileBookmarks else { return nil }
        if let cached = ThumbnailCache.shared.fileThumbnail(forID: item.id) {
            return cached
        }

        for bookmark in bookmarks {
            guard let url = resolveFileURL(bookmark: bookmark),
                  let image = await FileThumbnailLoader.generate(url: url, side: 40)
            else { continue }
            ThumbnailCache.shared.setFileThumbnail(image, forID: item.id)
            return image
        }
        return nil
    }

    private func resolveFileURL(bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmark,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    private func swiftUIColor(_ color: ParsedColor) -> Color {
        Color(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
    }

    // MARK: - Title

    private var title: some View {
        Text(item.previewText)
            .font(titleFont)
            .fontWeight(.semibold)
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
    }

    private var titleFont: Font {
        switch item.kind {
        case .code, .color:
            return .system(size: 16, weight: .semibold, design: .monospaced)
        default:
            return .system(size: 16, weight: .semibold)
        }
    }

    // MARK: - Metadata

    private var metadataRow: some View {
        HStack(spacing: 5) {
            ForEach(Array(metadataPieces.enumerated()), id: \.offset) { index, piece in
                if index > 0 {
                    Text(verbatim: "·")
                        .foregroundStyle(.quaternary)
                }
                piece
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var timeText: some View {
        Text(item.createdAt, format: .relative(presentation: .numeric))
            .monospacedDigit()
    }

    private var metadataPieces: [AnyView] {
        var pieces: [AnyView] = []
        if let app = item.sourceAppName, !app.isEmpty {
            pieces.append(AnyView(Text(app)))
        }
        pieces.append(AnyView(timeText))
        for detail in extraMetadataDetails {
            pieces.append(AnyView(Text(detail)))
        }
        return pieces
    }

    private var extraMetadataDetails: [String] {
        guard item.kind == .files else { return [] }
        let names = item.fileNames ?? []
        var details: [String] = []
        if names.count > 1 {
            details.append("\(names.count) files")
        } else if let first = names.first {
            let ext = (first as NSString).pathExtension
            if !ext.isEmpty { details.append(".\(ext.lowercased())") }
        }
        return details
    }
}

private struct Checkerboard: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let columns = Int(ceil(canvasSize.width / size))
            let rows = Int(ceil(canvasSize.height / size))
            for row in 0..<rows {
                for column in 0..<columns where (row + column).isMultiple(of: 2) {
                    let rect = CGRect(
                        x: CGFloat(column) * size,
                        y: CGFloat(row) * size,
                        width: size,
                        height: size
                    )
                    context.fill(Path(rect), with: .color(Color.primary.opacity(0.14)))
                }
            }
        }
        .background(Color.primary.opacity(0.05))
    }
}

extension ItemKind {
    var symbolName: String {
        switch self {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "eyedropper"
        case .image: return "photo"
        case .files: return "doc"
        }
    }
}
