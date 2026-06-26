import AppKit

struct SourceAppResolver {
    func currentSourceApp() -> SourceApp? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return SourceApp(
            bundleIdentifier: app.bundleIdentifier,
            localizedName: app.localizedName
        )
    }
}
