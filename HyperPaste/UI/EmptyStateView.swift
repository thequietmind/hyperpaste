import SwiftUI

struct EmptyStateView: View {
    var systemImage: String = "tray"
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.tertiary)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                if let message {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Empty history") {
    EmptyStateView(
        systemImage: "doc.on.clipboard",
        title: "Nothing copied yet",
        message: "Items you copy will appear here."
    )
    .frame(width: 420, height: 540)
    .background(.regularMaterial)
}

#Preview("No search results") {
    EmptyStateView(
        systemImage: "magnifyingglass",
        title: "No matches",
        message: "Try a shorter query or a different filter."
    )
    .frame(width: 420, height: 540)
    .background(.regularMaterial)
}
