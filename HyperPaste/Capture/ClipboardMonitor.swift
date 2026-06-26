import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    private let store: ClipboardStore
    private let classifier: PasteboardClassifier
    private let reader: PasteboardReader
    private let sourceResolver: SourceAppResolver
    private let pasteboard: NSPasteboard
    private let pollInterval: Duration

    private var lastChangeCount: Int
    private var task: Task<Void, Never>?

    init(
        store: ClipboardStore,
        classifier: PasteboardClassifier,
        reader: PasteboardReader,
        sourceResolver: SourceAppResolver,
        pasteboard: NSPasteboard,
        pollInterval: Duration
    ) {
        self.store = store
        self.classifier = classifier
        self.reader = reader
        self.sourceResolver = sourceResolver
        self.pasteboard = pasteboard
        self.pollInterval = pollInterval
        self.lastChangeCount = pasteboard.changeCount
    }

    convenience init(
        store: ClipboardStore,
        classifier: PasteboardClassifier
    ) {
        self.init(
            store: store,
            classifier: classifier,
            reader: PasteboardReader(),
            sourceResolver: SourceAppResolver(),
            pasteboard: .general,
            pollInterval: .milliseconds(250)
        )
    }

    func start() {
        guard task == nil else { return }
        task = Task { @MainActor [weak self] in
            await self?.runLoop()
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func runLoop() async {
        while !Task.isCancelled {
            await tick()
            try? await Task.sleep(for: pollInterval)
        }
    }

    private func tick() async {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        let sourceApp = sourceResolver.currentSourceApp()
        let snapshot = await reader.snapshot(of: pasteboard)
        let result = classifier.classify(
            snapshot: snapshot,
            sourceBundleID: sourceApp?.bundleIdentifier
        )

        switch result {
        case .classified(let classified):
            do {
                try store.insert(classified, sourceApp: sourceApp)
            } catch {
                NSLog("HyperPaste: insert failed: \(error)")
            }
        case .skipped:
            // Audit log lands in M5.
            break
        }
    }
}
