import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleHistory = Self(
        "toggleHistory",
        initial: .init(.c, modifiers: [.command, .shift])
    )
}
