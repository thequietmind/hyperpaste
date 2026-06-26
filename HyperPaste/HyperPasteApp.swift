import SwiftUI
import AppKit

@main
struct HyperPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let sharedStore: ClipboardStore
    private let loginItemService = LoginItemService()

    init() {
        do {
            self.sharedStore = try ClipboardStore()
            loginItemService.enableByDefaultIfNeeded()
        } catch {
            fatalError("HyperPaste: failed to initialize ClipboardStore: \(error)")
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenuContent(appDelegate: appDelegate)
        } label: {
            MenuBarLabelView(appDelegate: appDelegate, store: sharedStore)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
        }
    }
}

private struct MenuBarLabelView: View {
    let appDelegate: AppDelegate
    let store: ClipboardStore

    var body: some View {
        Image(systemName: "doc.on.clipboard")
            .task {
                appDelegate.attachStore(store)
            }
    }
}

private struct MenuBarMenuContent: View {
    let appDelegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Show Clipboard History") {
            appDelegate.showHistory()
        }

        Divider()

        Button("Settings…") {
            openSettings()
            Task { @MainActor in
                await Task.yield()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit HyperPaste") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

