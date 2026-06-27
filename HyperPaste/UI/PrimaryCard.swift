import SwiftUI

struct PrimaryCard<Content: View>: View {
    var cornerRadius: CGFloat = 12
    var horizontalPadding: CGFloat = 12
    var verticalPadding: CGFloat = 8
    var isSelected: Bool = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fillStyle)
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.55), lineWidth: 1)
                }
            }
    }

    private var fillStyle: AnyShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.16))
        }
        return AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
}

#Preview("Primary card states") {
    VStack(spacing: 8) {
        PrimaryCard {
            row(title: "Resting card", subtitle: "Today, 09:43 · Safari")
        }
        PrimaryCard(isSelected: true) {
            row(title: "Selected card", subtitle: "Today, 09:41 · Finder")
        }
        PrimaryCard {
            row(title: "Resting again", subtitle: "Today, 09:38 · Code")
        }
    }
    .padding(12)
    .frame(width: 420)
    .background(.regularMaterial)
}

@ViewBuilder
private func row(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
        Text(title)
            .font(.body)
            .fontWeight(.medium)
        Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
