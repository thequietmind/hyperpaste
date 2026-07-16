import AppKit
import SwiftUI
import KeyboardShortcuts

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var store: ClipboardStore?
    private(set) var monitor: ClipboardMonitor?
    private(set) var panelController: HistoryPanelController?
    private(set) var autoPaster: AutoPaster?
    private(set) var onboardingPresenter: AutoPasteOnboardingPresenter?
    private var statusItem: NSStatusItem?
    private var statusItemMenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let store = try ClipboardStore()
            attachStore(store)
        } catch {
            fatalError("HyperPaste: failed to initialize ClipboardStore: \(error)")
        }
        LoginItemService().enableByDefaultIfNeeded()
        configureStatusItem()
        KeyboardShortcuts.onKeyDown(for: .toggleHistory) { [weak self] in
            Task { @MainActor [weak self] in
                self?.showHistory()
            }
        }
    }

    func showHistory() {
        panelController?.show()
    }

    func requestClearHistory() {
        panelController?.requestClearHistory()
    }

    func attachStore(_ store: ClipboardStore) {
        guard self.store == nil else { return }
        self.store = store
        let monitor = ClipboardMonitor(
            store: store,
            classifier: PasteboardClassifier()
        )
        self.monitor = monitor
        monitor.start()
        let autoPaster = AutoPaster()
        let onboardingPresenter = AutoPasteOnboardingPresenter()
        self.autoPaster = autoPaster
        self.onboardingPresenter = onboardingPresenter
        self.panelController = HistoryPanelController(
            store: store,
            autoPaster: autoPaster,
            onboardingPresenter: onboardingPresenter
        )
    }

    // MARK: - Status item

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem
        statusItemMenu = NSHostingMenu(rootView: MenuBarMenuContent(appDelegate: self))
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "HyperPaste"
        )
        button.target = self
        button.action = #selector(handleStatusItemClick)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: String(localized: "Show Menu")) { [weak self] in
                MainActor.assumeIsolated {
                    self?.showStatusItemMenu()
                }
                return true
            }
        ])
    }

    @objc private func handleStatusItemClick() {
        if Self.isSecondaryClick(NSApp.currentEvent) {
            showStatusItemMenu()
        } else {
            panelController?.toggle()
        }
    }

    private static func isSecondaryClick(_ event: NSEvent?) -> Bool {
        // currentEvent is the last event the app processed, not necessarily
        // the one that triggered this action: accessibility activation
        // (AXPress) reaches the action without a fresh click event. Only a
        // just-delivered mouse-up counts as a click; everything else falls
        // through to the primary action, and the "Show Menu" accessibility
        // custom action covers the menu.
        guard let event,
              event.type == .rightMouseUp || event.type == .leftMouseUp,
              ProcessInfo.processInfo.systemUptime - event.timestamp < 1
        else {
            return false
        }
        return event.type == .rightMouseUp || event.modifierFlags.contains(.control)
    }

    private func showStatusItemMenu() {
        guard let statusItem, let statusItemMenu else { return }
        // Attaching a menu makes it swallow every click, so it is attached
        // only for the synthesized click and detached again afterwards.
        statusItem.menu = statusItemMenu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // SettingsLink opens the Settings scene without activating an accessory
    // app, leaving the window behind other applications' windows (or in the
    // Dock, if it was miniaturized).
    func bringSettingsWindowForward() {
        Task { @MainActor in
            for _ in 0..<40 {
                if let window = Self.settingsWindow() {
                    if window.isMiniaturized {
                        window.deminiaturize(nil)
                    }
                    NSApp.activate(ignoringOtherApps: true)
                    window.makeKeyAndOrderFront(nil)
                    return
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            // The identifier is a SwiftUI implementation detail; if it ever
            // stops matching, activating still brings the app's windows
            // forward.
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private static let settingsWindowIdentifier = "com_apple_SwiftUI_Settings_window"

    private static func settingsWindow() -> NSWindow? {
        NSApp.windows.first {
            $0.identifier?.rawValue == settingsWindowIdentifier
                || $0.frameAutosaveName == settingsWindowIdentifier
        }
    }
}
