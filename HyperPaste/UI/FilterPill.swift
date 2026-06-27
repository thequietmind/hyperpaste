import SwiftUI

struct FilterPill: View {
    let title: LocalizedStringKey
    var systemImage: String? = nil
    var isSelected: Bool = false
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 4)
            .frame(minHeight: 24)
            .foregroundStyle(foreground)
            .background {
                Capsule(style: .continuous)
                    .fill(fill)
            }
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .onHover { isHovering = $0 }
        .animation(reduceMotion ? nil : .snappy, value: isSelected)
        .animation(reduceMotion ? nil : .snappy, value: isHovering)
    }

    private var foreground: Color {
        isSelected ? Color.white : Color.secondary
    }

    private var fill: Color {
        if isSelected {
            return Color.accentColor
        }
        if isHovering {
            return Color.accentColor.opacity(0.09)
        }
        return Color.clear
    }
}

#Preview("Filter row") {
    let selection = "Files"
    let labels: [(String, String)] = [
        ("All", "tray.full"),
        ("Links", "link"),
        ("Code", "chevron.left.forwardslash.chevron.right"),
        ("Text", "text.alignleft"),
        ("Files", "doc.on.doc"),
        ("Pinned", "pin.fill")
    ]
    return HStack(spacing: 6) {
        ForEach(labels, id: \.0) { label, symbol in
            FilterPill(
                title: LocalizedStringKey(label),
                systemImage: symbol,
                isSelected: label == selection
            ) {}
        }
    }
    .padding(12)
    .background(.regularMaterial)
}
