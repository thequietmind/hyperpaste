import SwiftUI

struct SearchField: View {
    var prompt: LocalizedStringKey = "Search"
    @Binding var text: String
    @Binding var externalFocus: Bool

    @FocusState private var isFocused: Bool

    init(
        prompt: LocalizedStringKey = "Search",
        text: Binding<String>,
        isFocused: Binding<Bool> = .constant(false)
    ) {
        self.prompt = prompt
        _text = text
        _externalFocus = isFocused
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                    externalFocus = true
                    isFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(minHeight: 28)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        }
        .hoverFocusRing(cornerRadius: 8, isFocused: isFocused, showsHoverBackground: false)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        SearchField(text: text)
            .padding(12)
            .frame(width: 360)
            .background(.regularMaterial)
    }
}

#Preview("With text") {
    StatefulPreview(initial: "pasly") { text in
        SearchField(text: text)
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
