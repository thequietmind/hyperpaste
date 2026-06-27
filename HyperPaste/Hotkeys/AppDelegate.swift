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

    func applicationDidFinishLaunching(_ notification: Notification) {
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
}
