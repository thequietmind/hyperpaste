import AppKit
import SwiftUI

@MainActor
final class AutoPasteOnboardingPresenter {
    static let userDefaultsKey = "hasSeenAutoPasteOnboarding"

    private let defaults: UserDefaults
    private var presentedWindow: NSWindow?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasBeenSeen: Bool {
        defaults.bool(forKey: Self.userDefaultsKey)
    }

    func markSeen() {
        defaults.set(true, forKey: Self.userDefaultsKey)
    }

    func presentIfNeeded(autoPaster: AutoPaster) {
        guard !hasBeenSeen else { return }
        guard presentedWindow == nil else { return }

        let panel = OnboardingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 168),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isOpaque = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false

        let hosting = NSHostingController(
            rootView: AutoPasteOnboardingCard(
                onOpenSettings: { [weak self] in
                    autoPaster.openAccessibilitySettings()
                    self?.dismissAndMark()
                },
                onDismiss: { [weak self] in
                    self?.dismissAndMark()
                }
            )
        )
        hosting.sizingOptions = [.intrinsicContentSize]
        panel.contentViewController = hosting

        positionTopRight(panel: panel)
        panel.orderFrontRegardless()

        presentedWindow = panel
    }

    private func dismissAndMark() {
        markSeen()
        presentedWindow?.orderOut(nil)
        presentedWindow = nil
    }

    private func positionTopRight(panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }
        let size = panel.frame.size
        let margin: CGFloat = 16
        let origin = NSPoint(
            x: visible.maxX - size.width - margin,
            y: visible.maxY - size.height - margin
        )
        panel.setFrameOrigin(origin)
    }
}

private final class OnboardingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct AutoPasteOnboardingCard: View {
    let onOpenSettings: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "command.square.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Enable Paste from HyperPaste")
                    .font(.headline)
                Spacer(minLength: 0)
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            Text("To paste selected history items automatically, allow HyperPaste in System Settings → Privacy & Security → Accessibility. Until then, selected items will still be copied to your clipboard.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Spacer()
                Button("Done", action: onDismiss)
                Button("Open System Settings", action: onOpenSettings)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 360)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

#Preview("Auto-paste onboarding card") {
    AutoPasteOnboardingCard(onOpenSettings: {}, onDismiss: {})
        .padding(24)
        .frame(width: 420)
}
