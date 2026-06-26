import Foundation
import Carbon.HIToolbox
import CoreGraphics
import Testing
@testable import HyperPaste

@MainActor
@Suite("AutoPaster")
struct AutoPasterTests {
    @Test("status reflects the injected trust check")
    func statusReflectsTrustCheck() {
        let granted = AutoPaster(trustCheck: { true })
        #expect(granted.status == .granted)

        let denied = AutoPaster(trustCheck: { false })
        #expect(denied.status == .denied)
    }

    @Test("handOffAndPaste does not post events when permission is denied")
    func handOffSkipsPostWhenDenied() async {
        let posted = PostedEventsBox()
        let paster = AutoPaster(
            trustCheck: { false },
            activationTimeout: .milliseconds(0),
            eventPoster: { down, up in
                posted.record(down: down, up: up)
            }
        )

        await paster.handOffAndPaste(to: nil)

        #expect(posted.count == 0)
    }

    @Test("handOffAndPaste does not post events when target app is nil")
    func handOffSkipsPostWhenTargetMissing() async {
        let posted = PostedEventsBox()
        let paster = AutoPaster(
            trustCheck: { true },
            activationTimeout: .milliseconds(0),
            eventPoster: { down, up in
                posted.record(down: down, up: up)
            }
        )

        await paster.handOffAndPaste(to: nil)

        #expect(posted.count == 0)
    }

    @Test("PasteKeystroke targets the V key with the command modifier")
    func pasteKeystrokeShape() {
        #expect(PasteKeystroke.virtualKeyV == CGKeyCode(kVK_ANSI_V))
        #expect(PasteKeystroke.modifierFlags.contains(.maskCommand))

        let source = CGEventSource(stateID: .combinedSessionState)
        let events = PasteKeystroke.makeEvents(source: source)
        #expect(events.down?.flags.contains(.maskCommand) == true)
        #expect(events.up?.flags.contains(.maskCommand) == true)
        #expect(events.down?.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_ANSI_V))
        #expect(events.up?.getIntegerValueField(.keyboardEventKeycode) == Int64(kVK_ANSI_V))
    }
}

@MainActor
private final class PostedEventsBox {
    private(set) var count = 0

    func record(down: CGEvent?, up: CGEvent?) {
        count += 1
        _ = down
        _ = up
    }
}
