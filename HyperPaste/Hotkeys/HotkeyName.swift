import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleHistory = Self(
        "toggleHistory",
        initial: .init(.x, modifiers: [.command, .control])
    )

    static let showPinnedHistory = Self(
        "showPinnedHistory",
        initial: .init(.x, modifiers: [.command, .control, .shift])
    )

    /// Every global shortcut HyperPaste registers. Two of them sharing a key
    /// combination would fire both actions at once, so Settings keeps them
    /// distinct.
    static let hyperPasteShortcuts: [Self] = [.toggleHistory, .showPinnedHistory]

    /// The other HyperPaste shortcut that is already assigned `shortcut`, if any.
    func conflict(with shortcut: KeyboardShortcuts.Shortcut) -> Self? {
        conflict(with: shortcut, lookup: KeyboardShortcuts.getShortcut(for:))
    }

    func conflict(
        with shortcut: KeyboardShortcuts.Shortcut,
        lookup: (Self) -> KeyboardShortcuts.Shortcut?
    ) -> Self? {
        Self.hyperPasteShortcuts.first { $0 != self && lookup($0) == shortcut }
    }
}
