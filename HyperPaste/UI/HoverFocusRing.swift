import SwiftUI

struct HoverFocusRing: ViewModifier {
    var cornerRadius: CGFloat = 8
    var isFocused: Bool = false
    var showsHoverBackground: Bool = true

    @State private var isHovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background {
                if showsHoverBackground {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.accentColor.opacity(isHovering ? 0.06 : 0))
                }
            }
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 2)
                }
            }
            .onHover { hovering in
                isHovering = hovering
            }
            .animation(reduceMotion ? nil : .snappy, value: isHovering)
            .animation(reduceMotion ? nil : .snappy, value: isFocused)
    }
}

extension View {
    func hoverFocusRing(
        cornerRadius: CGFloat = 8,
        isFocused: Bool = false,
        showsHoverBackground: Bool = true
    ) -> some View {
        modifier(
            HoverFocusRing(
                cornerRadius: cornerRadius,
                isFocused: isFocused,
                showsHoverBackground: showsHoverBackground
            )
        )
    }
}

#Preview("Hover & focus states") {
    VStack(spacing: 16) {
        Text("Hover me")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .hoverFocusRing(cornerRadius: 8)

        Text("Focused")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .hoverFocusRing(cornerRadius: 8, isFocused: true)

        Text("Hover only — no focus ring")
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .hoverFocusRing(cornerRadius: 12, isFocused: false)
    }
    .padding(32)
    .frame(width: 320)
    .background(.regularMaterial)
}
