import AppKit
import SwiftUI
import SwiftData

@MainActor
final class HistoryPanelController: NSObject {
    private let store: ClipboardStore
    private let autoPaster: AutoPaster
    private let onboardingPresenter: AutoPasteOnboardingPresenter
    private var panel: NSPanel?
    private var deleteKeyMonitor: Any?
    private var previousApplication: NSRunningApplication?

    private static let panelSize = NSSize(width: 600, height: 600)

    init(
        store: ClipboardStore,
        autoPaster: AutoPaster,
        onboardingPresenter: AutoPasteOnboardingPresenter
    ) {
        self.store = store
        self.autoPaster = autoPaster
        self.onboardingPresenter = onboardingPresenter
    }

    func show() {
        try? store.pruneUnavailableFileItems()
        let panel = self.panel ?? makePanel()
        self.panel = panel
        previousApplication = Self.currentExternalFrontmostApplication()

        let host = HistoryHostingController(
            rootView: HistoryView(
                attachmentStore: store.attachmentStore,
                onDismiss: { [weak self] in self?.dismiss() },
                onCommit: { [weak self] in self?.commitAndDismiss() },
                onRequestDeleteItem: { [weak self] item in
                    self?.presentDeleteConfirmation(for: item)
                },
                onRequestDeleteItems: { [weak self] items in
                    self?.presentDeleteConfirmation(for: items)
                },
                onRequestTogglePin: { [weak self] item in
                    self?.togglePinned(for: item)
                }
            )
            .modelContainer(store.container)
        )
        panel.contentViewController = host
        panel.setFrame(NSRect(origin: panel.frame.origin, size: Self.panelSize), display: false)

        positionCentered(panel: panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installDeleteKeyMonitorIfNeeded()
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    private func commitAndDismiss() {
        let target = previousApplication
        previousApplication = nil
        dismiss()

        switch autoPaster.status {
        case .granted:
            Task { [autoPaster] in
                await autoPaster.handOffAndPaste(to: target)
            }
        case .denied:
            autoPaster.requestAccessibilityAccess()
            target?.activate(options: [])
            onboardingPresenter.presentIfNeeded(autoPaster: autoPaster)
        }
    }

    private func installDeleteKeyMonitorIfNeeded() {
        guard deleteKeyMonitor == nil else { return }
        deleteKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let panel = self?.panel else { return event }
            let sheet = panel.attachedSheet
            guard event.window === panel || event.window === sheet else {
                return event
            }

            if Self.tabKeyCodes.contains(event.keyCode),
               event.modifierFlags.contains(.control),
               event.modifierFlags.intersection(Self.controlTabIgnoredModifierFlags).isEmpty {
                let command: HistoryPanelKeyCommand = event.modifierFlags.contains(.shift)
                    ? .selectPreviousFilter
                    : .selectNextFilter
                command.post(from: panel)
                return nil
            }

            guard event.modifierFlags.intersection(Self.commandModifierFlags).isEmpty else { return event }

            if let sheet {
                if Self.returnKeyCodes.contains(event.keyCode),
                   Self.performDeleteButton(in: sheet) {
                    return nil
                }
                return event
            }

            if Self.deleteKeyCodes.contains(event.keyCode) {
                if let textEditor = panel.firstResponder as? NSText,
                   !textEditor.string.isEmpty {
                    return event
                }
                HistoryPanelKeyCommand.delete.post(from: panel)
                return nil
            }

            guard let command = HistoryPanelKeyCommand(keyCode: event.keyCode) else { return event }
            if command.isTextEditingNavigation, Self.isEditingText(in: panel) {
                return event
            }
            command.post(
                from: panel,
                extendsSelection: event.modifierFlags.contains(.shift)
            )
            return nil
        }
    }

    private static let deleteKeyCodes: Set<UInt16> = [51, 117]
    private static let returnKeyCodes: Set<UInt16> = [36, 76]
    private static let tabKeyCodes: Set<UInt16> = [48]
    private static let commandModifierFlags: NSEvent.ModifierFlags = [.command, .option, .control]
    private static let controlTabIgnoredModifierFlags: NSEvent.ModifierFlags = [.command, .option]

    private static func isEditingText(in panel: NSPanel) -> Bool {
        if panel.firstResponder is NSText { return true }
        if let textInput = panel.firstResponder as? NSTextInputClient,
           textInput.hasMarkedText() {
            return true
        }
        return false
    }

    private static func performDeleteButton(in window: NSWindow) -> Bool {
        guard let button = deleteButton(in: window.contentView) else { return false }
        button.performClick(nil)
        return true
    }

    private static func deleteButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton,
           button.title == String(localized: "Delete") {
            return button
        }
        for subview in view.subviews {
            if let button = deleteButton(in: subview) {
                return button
            }
        }
        return nil
    }

    private static func currentExternalFrontmostApplication() -> NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.bundleIdentifier != Bundle.main.bundleIdentifier
        else {
            return nil
        }
        return app
    }

    func requestClearHistory() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Clear history?")
        alert.informativeText = String(localized: "This will remove all clipboard history.")
        let clearButton = alert.addButton(withTitle: String(localized: "Clear"))
        clearButton.hasDestructiveAction = true
        alert.addButton(withTitle: String(localized: "Cancel"))

        if let panel, panel.isVisible {
            alert.beginSheetModal(for: panel) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                try? self?.store.clearAll()
            }
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        try? store.clearAll()
    }

    private func togglePinned(for item: ClipboardItem) {
        try? store.setPinned(item, pinned: item.pinnedAt == nil)
    }

    private func presentDeleteConfirmation(for item: ClipboardItem) {
        presentDeleteConfirmation(for: [item])
    }

    private func presentDeleteConfirmation(for items: [ClipboardItem]) {
        guard let panel, !items.isEmpty else { return }
        let alert = NSAlert()
        if items.count == 1 {
            alert.messageText = String(localized: "Delete item?")
            alert.informativeText = String(localized: "This will remove this item from your clipboard history.")
        } else {
            alert.messageText = String(localized: "Delete items?")
            alert.informativeText = String(localized: "This will remove the selected items from your clipboard history.")
        }
        let deleteButton = alert.addButton(withTitle: String(localized: "Delete"))
        deleteButton.hasDestructiveAction = true
        deleteButton.keyEquivalent = "\r"
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            for item in items {
                ThumbnailCache.shared.evict(id: item.id)
            }
            try? self?.store.delete(items)
        }
    }

    // MARK: - Panel construction

    private func makePanel() -> NSPanel {
        let contentRect = NSRect(origin: .zero, size: Self.panelSize)
        let panel = HistoryPanel(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self
        return panel
    }

    private func positionCentered(panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let panelSize = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - panelSize.width / 2,
            y: visible.midY - panelSize.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}

extension HistoryPanelController: NSWindowDelegate {
    func windowDidResignKey(_ notification: Notification) {
        if panel?.attachedSheet != nil { return }
        dismiss()
    }
}

private final class HistoryPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

extension Notification.Name {
    static let historyPanelKeyCommand = Notification.Name("HyperPaste.historyPanelKeyCommand")
}

enum HistoryPanelKeyCommand: String {
    case moveUp
    case moveDown
    case selectPreviousFilter
    case selectNextFilter
    case commit
    case escape
    case delete

    private static let userInfoKey = "command"
    private static let extendsSelectionUserInfoKey = "extendsSelection"

    init?(keyCode: UInt16) {
        switch keyCode {
        case 126:
            self = .moveUp
        case 125:
            self = .moveDown
        case 123:
            self = .selectPreviousFilter
        case 124:
            self = .selectNextFilter
        case 36, 76:
            self = .commit
        case 53:
            self = .escape
        default:
            return nil
        }
    }

    init?(notification: Notification) {
        guard let rawValue = notification.userInfo?[Self.userInfoKey] as? String else { return nil }
        self.init(rawValue: rawValue)
    }

    var isTextEditingNavigation: Bool {
        switch self {
        case .selectPreviousFilter, .selectNextFilter:
            return true
        case .moveUp, .moveDown, .commit, .escape, .delete:
            return false
        }
    }

    static func extendsSelection(_ notification: Notification) -> Bool {
        notification.userInfo?[Self.extendsSelectionUserInfoKey] as? Bool == true
    }

    func post(from panel: NSPanel, extendsSelection: Bool = false) {
        NotificationCenter.default.post(
            name: .historyPanelKeyCommand,
            object: panel,
            userInfo: [
                Self.userInfoKey: rawValue,
                Self.extendsSelectionUserInfoKey: extendsSelection
            ]
        )
    }
}

private final class HistoryHostingController<Content: View>: NSHostingController<Content> {
    override func loadView() {
        view = FirstMouseHostingView(rootView: rootView)
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    required init(rootView: Content) {
        super.init(rootView: rootView)
        focusRingType = .none
    }

    @MainActor @preconcurrency required dynamic init?(coder: NSCoder) {
        super.init(coder: coder)
        focusRingType = .none
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
