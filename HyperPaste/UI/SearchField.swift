import SwiftUI

struct SearchField<Accessory: View>: View {
    var prompt: LocalizedStringKey = "Search"
    @Binding var text: String
    @Binding var externalFocus: Bool
    @ViewBuilder var accessory: () -> Accessory

    @FocusState private var isFocused: Bool

    init(
        prompt: LocalizedStringKey = "Search",
        text: Binding<String>,
        isFocused: Binding<Bool> = .constant(false),
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.prompt = prompt
        _text = text
        _externalFocus = isFocused
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.body)
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .font(.body)
                .focused($isFocused)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                    externalFocus = true
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            accessory()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(minHeight: 32)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        }
        .hoverFocusRing(cornerRadius: 9, isFocused: isFocused, showsHoverBackground: false)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onTapGesture {
            externalFocus = true
            isFocused = true
        }
        .onAppear {
            isFocused = externalFocus
        }
        .onChange(of: externalFocus) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            externalFocus = newValue
        }
    }
}

#Preview("Empty") {
    StatefulPreview { text in
        SearchField(prompt: "Search your clipboard…", text: text) {
            Text("7 items")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 360)
        .background(.regularMaterial)
    }
}

#Preview("With text") {
    StatefulPreview(initial: "pasly") { text in
        SearchField(prompt: "Search your clipboard…", text: text) {
            Text("3 items")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 360)
        .background(.regularMaterial)
    }
}

private struct StatefulPreview<Content: View>: View {
    @State private var text: String
    let content: (Binding<String>) -> Content

    init(initial: String = "", @ViewBuilder content: @escaping (Binding<String>) -> Content) {
        _text = State(initialValue: initial)
        self.content = content
    }

    var body: some View {
        content($text)
    }
}
