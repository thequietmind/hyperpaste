import SwiftUI
import AppKit

struct ItemCardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onRequestDelete: () -> Void
    let onRequestTogglePin: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPinned: Bool { item.pinnedAt != nil }
    private var pinMenuTitle: LocalizedStringKey { isPinned ? "Unpin" : "Pin" }
    private var parsedColor: ParsedColor? {
        guard item.kind == .color, let text = item.text else { return nil }
        return ColorParser.parse(text)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            badge

            VStack(alignment: .leading, spacing: 2) {
                title
                metadataRow
            }

            Spacer(minLength: 8)

            if isPinned {
                Image(systemName: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                    .accessibilityLabel("Pinned")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(rowFill)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .smooth(duration: 0.22), value: isSelected)
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: isHovering)
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
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isHovering { return Color.primary.opacity(0.04) }
        return .clear
    }

    // MARK: - Badge

    @ViewBuilder
    private var badge: some View {
        if item.kind == .color, let parsedColor {
            colorBadge(for: parsedColor)
        } else {
            ZStack {
                Circle()
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.55))
                Image(systemName: item.kind.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 32, height: 32)
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
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .accessibilityHidden(true)
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
            return .system(.body, design: .monospaced)
        default:
            return .body
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
        .font(.footnote)
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
