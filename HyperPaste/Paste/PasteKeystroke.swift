import CoreGraphics
import Carbon.HIToolbox

enum PasteKeystroke {
    static let virtualKeyV: CGKeyCode = CGKeyCode(kVK_ANSI_V)
    static let modifierFlags: CGEventFlags = .maskCommand

    static func makeEvents(source: CGEventSource?) -> (down: CGEvent?, up: CGEvent?) {
        let down = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: virtualKeyV, keyDown: false)
        down?.flags = modifierFlags
        up?.flags = modifierFlags
        return (down, up)
    }
}
