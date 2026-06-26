import AppKit
import ApplicationServices

enum AutoPasterStatus: Equatable {
    case granted
    case denied
}

@MainActor
final class AutoPaster {
    private let trustCheck: () -> Bool
    private let activationTimeout: Duration
    private let eventPoster: (CGEvent?, CGEvent?) -> Void

    init(
        trustCheck: @escaping () -> Bool = { AXIsProcessTrusted() },
        activationTimeout: Duration = .milliseconds(200),
        eventPoster: ((CGEvent?, CGEvent?) -> Void)? = nil
    ) {
        self.trustCheck = trustCheck
        self.activationTimeout = activationTimeout
        self.eventPoster = eventPoster ?? Self.defaultEventPoster
    }

    var status: AutoPasterStatus {
        trustCheck() ? .granted : .denied
    }

    @discardableResult
    func requestAccessibilityAccess() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        requestAccessibilityAccess()
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    func handOffAndPaste(to app: NSRunningApplication?) async {
        guard status == .granted else { return }
        guard let app else { return }

        if !app.isActive {
            app.activate(options: [])
            try? await Task.sleep(for: activationTimeout)
        }

        synthesizePaste()
    }

    private func synthesizePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        let events = PasteKeystroke.makeEvents(source: source)
        eventPoster(events.down, events.up)
    }

    private static let defaultEventPoster: (CGEvent?, CGEvent?) -> Void = { down, up in
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
}
