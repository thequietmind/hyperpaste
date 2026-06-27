import SwiftUI
import AppKit

struct ItemCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let attachmentStore: AttachmentStore?
    let onRequestDelete: () -> Void
    let onRequestTogglePin: () -> Void

    @State private var fileImagePreview: NSImage?
    @State private var isHovering = false

    private var isPinned: Bool { item.pinnedAt != nil }
    private var pinSystemImage: String { isPinned ? "pin.fill" : "pin" }
    private var pinActionLabel: LocalizedStringKey { isPinned ? "Unpin item" : "Pin item" }
    private var pinMenuTitle: LocalizedStringKey { isPinned ? "Unpin" : "Pin" }
    private var parsedColor: ParsedColor? {
        guard item.kind == .color, let text = item.text else { return nil }
        return ColorParser.parse(text)
    }

    var body: some View {
        PrimaryCard(isSelected: isSelected) {
            HStack(alignment: .top, spacing: 10) {
                leading
                VStack(alignment: .leading, spacing: 4) {
                    title
                    metadataRow
                }
                Spacer(minLength: 0)
                trailingActions
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(pinMenuTitle) {
                requestTogglePin()
            }
            Divider()
            Button("Delete", role: .destructive) {
                onRequestDelete()
            }
        }
    }

    @ViewBuilder
    private var trailingActions: some View {
        let hoverVisible = isHovering || isSelected
        HStack(spacing: 6) {
            ItemActionButton(systemImage: pinSystemImage, label: pinActionLabel) {
                requestTogglePin()
            }
            ItemActionButton(systemImage: "trash", label: "Delete item") {
                onRequestDelete()
            }
        }
        .opacity(hoverVisible ? 1 : 0)
        .allowsHitTesting(hoverVisible)
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isPinned)
    }

    private func requestTogglePin() {
        onRequestTogglePin()
    }

    // MARK: - Leading

    @ViewBuilder
    private var leading: some View {
        switch item.kind {
        case .text, .link, .code, .color:
            Image(systemName: item.kind.symbolName)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18, alignment: .top)
                .padding(.top, 1)
        case .image:
            imageThumbnail
        case .files:
            fileIcon
        }
    }

    @ViewBuilder
    private var imageThumbnail: some View {
        if let attachmentStore,
           let nsImage = ThumbnailCache.shared.thumbnail(for: item, attachmentStore: attachmentStore) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.medium)
                .scaledToFit()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            placeholderTile(systemImage: "photo")
        }
    }

    @ViewBuilder
    private var fileIcon: some View {
        Group {
            if let preview = fileImagePreview {
                Image(nsImage: preview)
                    .resizable()
                    .interpolation(.medium)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else if let url = firstResolvedURL {
                Image(nsImage: FileIconLoader.icon(forPath: url.path))
                    .resizable()
                    .scaledToFit()
            } else if let firstName = item.fileNames?.first {
                Image(nsImage: FileIconLoader.icon(forPath: firstName))
                    .resizable()
                    .scaledToFit()
                    .opacity(0.6)
            } else {
                placeholderTile(systemImage: "doc")
            }
        }
        .frame(width: 56, height: 56)
        .task(id: item.id) { await loadFilePreviewIfNeeded() }
    }

    private func loadFilePreviewIfNeeded() async {
        if let cached = ThumbnailCache.shared.fileThumbnail(forID: item.id) {
            fileImagePreview = cached
            return
        }
        guard let url = firstResolvedURL else { return }
        guard let preview = await FileThumbnailLoader.generate(url: url) else { return }
        ThumbnailCache.shared.setFileThumbnail(preview, forID: item.id)
        fileImagePreview = preview
    }

    private func placeholderTile(systemImage: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .quaternaryLabelColor))
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.tertiary)
        }
        .frame(width: 56, height: 56)
    }

    // MARK: - Title row

    private var title: some View {
        HStack(spacing: 6) {
            if let parsedColor {
                ColorSwatch(color: parsedColor)
            }
            Text(item.previewText)
                .font(titleFont)
                .fontWeight(.medium)
                .lineLimit(2)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
        }
    }

    private var titleFont: Font {
        item.kind == .code ? .system(.body, design: .monospaced) : .body
    }

    // MARK: - Metadata row

    private var metadataRow: some View {
        HStack(spacing: 6) {
            Text(item.createdAt, format: .relative(presentation: .numeric))
                .monospacedDigit()
            ForEach(metadataDetails, id: \.self) { detail in
                Text("·")
                Text(detail)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var metadataDetails: [String] {
        switch item.kind {
        case .image:
            var details: [String] = []
            if let app = item.sourceAppName, !app.isEmpty {
                details.append(app)
            }
            return details
        case .files:
            return fileDetails
        case .text, .link, .code, .color:
            if let app = item.sourceAppName, !app.isEmpty {
                return [app]
            }
            return []
        }
    }

    private var fileDetails: [String] {
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

    // MARK: - File availability

    private var firstResolvedURL: URL? {
        guard let blob = item.fileBookmarks?.first else { return nil }
        return PasteCoordinator.resolveForAvailability(bookmark: blob)
    }

}

private struct ColorSwatch: View {
    let color: ParsedColor

    private let size: CGFloat = 16
    private let checkerSize: CGFloat = 4

    var body: some View {
        ZStack {
            if color.alpha < 1 {
                Checkerboard(size: checkerSize)
            }
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(swiftUIColor)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private var swiftUIColor: Color {
        Color(
            red: color.red,
            green: color.green,
            blue: color.blue,
            opacity: color.alpha
        )
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
        case .color: return "paintpalette"
        case .image: return "photo"
        case .files: return "doc.on.doc"
        }
    }
}
