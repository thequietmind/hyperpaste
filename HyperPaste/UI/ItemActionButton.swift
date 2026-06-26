import SwiftUI

struct ItemActionButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    let action: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .focusable(true)
        .focused($isFocused)
        .hoverFocusRing(cornerRadius: 6, isFocused: isFocused)
        .accessibilityLabel(label)
        .help(label)
    }
}

#Preview("Action row") {
    HStack(spacing: 2) {
        ItemActionButton(systemImage: "arrow.up.right.square", label: "Open") {}
        ItemActionButton(systemImage: "folder", label: "Reveal in Finder") {}
        ItemActionButton(systemImage: "doc.on.doc", label: "Copy") {}
        ItemActionButton(systemImage: "pin", label: "Pin") {}
        ItemActionButton(systemImage: "trash", label: "Delete") {}
    }
    .padding(12)
    .background(.regularMaterial)
}
