import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") {
                GeneralSettingsView()
            }
        }
        .frame(width: 480, height: 310)
        .background(SettingsWindowConfigurator())
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureAfterWindowAttachment(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureAfterWindowAttachment(for: nsView)
    }

    private func configureAfterWindowAttachment(for view: NSView) {
        Task { @MainActor in
            await Task.yield()
            view.window?.collectionBehavior.insert(.moveToActiveSpace)
        }
    }
}

private struct GeneralSettingsView: View {
    @State private var startsAtLogin = false
    @State private var pasteStatus: AutoPasterStatus = .denied

    private let loginItemService = LoginItemService()
    private let autoPaster = AutoPaster()

    var body: some View {
        Form {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at login")
                    Text("Launch HyperPaste automatically when you log in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 16)

                Toggle("Start at login", isOn: Binding(
                    get: { startsAtLogin },
                    set: updateStartAtLogin
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }

            LabeledContent("Activation Shortcut") {
                shortcutRecorder(for: .toggleHistory)
            }

            LabeledContent {
                shortcutRecorder(for: .showPinnedHistory)
            } label: {
                Text("Pinned Items Shortcut")
                Text("Opens HyperPaste with the Pinned tab selected.")
            }

            LabeledContent("Paste") {
                pasteStatusContent
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshStatus() }
        .task {
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                refreshStatus()
            }
        }
    }

    private func shortcutRecorder(for name: KeyboardShortcuts.Name) -> some View {
        KeyboardShortcuts.Recorder(for: name)
            .shortcutValidation { shortcut in
                guard let conflict = name.conflict(with: shortcut) else { return .allow }
                return .disallow(reason: Self.conflictReason(for: conflict))
            }
    }

    private static func conflictReason(for name: KeyboardShortcuts.Name) -> String {
        name == .showPinnedHistory
            ? String(localized: "This shortcut is already used by the Pinned Items Shortcut.")
            : String(localized: "This shortcut is already used by the Activation Shortcut.")
    }

    @ViewBuilder
    private var pasteStatusContent: some View {
        switch pasteStatus {
        case .granted:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("Paste from HyperPaste is enabled")
                    .foregroundStyle(.secondary)
            }
        case .denied:
            VStack(alignment: .trailing, spacing: 4) {
                Button("Open System Settings…") {
                    autoPaster.openAccessibilitySettings()
                }
                Text("Allow HyperPaste in Accessibility to paste selected history items automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    private func updateStartAtLogin(_ enabled: Bool) {
        startsAtLogin = enabled
        if loginItemService.setEnabled(enabled) {
            refreshStatus()
        } else {
            startsAtLogin = loginItemService.isEnabled
        }
    }

    private func refreshStatus() {
        startsAtLogin = loginItemService.isEnabled
        pasteStatus = autoPaster.status
    }
}

#Preview {
    SettingsView()
}
