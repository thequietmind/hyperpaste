import SwiftUI
import AppKit

@main
struct HyperPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

struct MenuBarMenuContent: View {
    let appDelegate: AppDelegate

    var body: some View {
        Button {
            appDelegate.showHistory()
        } label: {
            Label("Show Clipboard History", systemImage: "clock.arrow.circlepath")
        }

        Divider()

        Button {
            appDelegate.requestClearHistory()
        } label: {
            Label("Clear Clipboard History…", systemImage: "trash")
        }

        Divider()

        SettingsLink {
            Label("Settings…", systemImage: "gearshape")
        }
        .buttonStyle(SettingsActivationButtonStyle(appDelegate: appDelegate))
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Label("Quit HyperPaste", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

private struct SettingsActivationButtonStyle: PrimitiveButtonStyle {
    let appDelegate: AppDelegate

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.trigger()
            appDelegate.bringSettingsWindowForward()
        } label: {
            configuration.label
        }
    }
}
