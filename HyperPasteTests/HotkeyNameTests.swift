import AppKit
import Testing
import KeyboardShortcuts
@testable import HyperPaste

@MainActor
@Suite("HotkeyName")
struct HotkeyNameTests {
    private let activation = KeyboardShortcuts.Shortcut(.x, modifiers: [.command, .control])
    private let pinned = KeyboardShortcuts.Shortcut(.x, modifiers: [.command, .control, .shift])

    @Test("Activation shortcut defaults to Control-Command-X")
    func activationDefault() {
        #expect(KeyboardShortcuts.Name.toggleHistory.initialShortcut == activation)
    }

    @Test("Pinned items shortcut defaults to Control-Shift-Command-X")
    func pinnedDefault() {
        #expect(KeyboardShortcuts.Name.showPinnedHistory.initialShortcut == pinned)
    }

    @Test("Default shortcuts do not conflict with each other")
    func defaultsAreDistinct() {
        let defaults = KeyboardShortcuts.Name.hyperPasteShortcuts.map(\.initialShortcut)
        #expect(Set(defaults).count == defaults.count)
    }

    @Test("Recording another action's shortcut reports that action")
    func detectsConflictWithOtherAction() {
        let assigned: [KeyboardShortcuts.Name: KeyboardShortcuts.Shortcut] = [
            .toggleHistory: activation,
            .showPinnedHistory: pinned
        ]
        let lookup = { (name: KeyboardShortcuts.Name) in assigned[name] }

        #expect(KeyboardShortcuts.Name.showPinnedHistory.conflict(with: activation, lookup: lookup) == .toggleHistory)
        #expect(KeyboardShortcuts.Name.toggleHistory.conflict(with: pinned, lookup: lookup) == .showPinnedHistory)
    }

    @Test("Re-recording an action's own shortcut is not a conflict")
    func ignoresOwnShortcut() {
        let assigned: [KeyboardShortcuts.Name: KeyboardShortcuts.Shortcut] = [
            .toggleHistory: activation,
            .showPinnedHistory: pinned
        ]
        let lookup = { (name: KeyboardShortcuts.Name) in assigned[name] }

        #expect(KeyboardShortcuts.Name.toggleHistory.conflict(with: activation, lookup: lookup) == nil)
        #expect(KeyboardShortcuts.Name.showPinnedHistory.conflict(with: pinned, lookup: lookup) == nil)
    }

    @Test("A cleared shortcut never conflicts")
    func clearedShortcutDoesNotConflict() {
        let assigned: [KeyboardShortcuts.Name: KeyboardShortcuts.Shortcut] = [
            .toggleHistory: activation
        ]
        let lookup = { (name: KeyboardShortcuts.Name) in assigned[name] }

        #expect(KeyboardShortcuts.Name.toggleHistory.conflict(with: pinned, lookup: lookup) == nil)
    }
}
