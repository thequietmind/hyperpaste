import Foundation
import Testing
@testable import HyperPaste

@MainActor
@Suite("AutoPasteOnboardingPresenter")
struct AutoPasteOnboardingPresenterTests {
    @Test("hasBeenSeen starts false on a fresh defaults suite")
    func hasBeenSeenStartsFalse() {
        let defaults = makeIsolatedDefaults()
        let presenter = AutoPasteOnboardingPresenter(defaults: defaults)
        #expect(!presenter.hasBeenSeen)
    }

    @Test("markSeen persists the seen flag")
    func markSeenPersists() {
        let defaults = makeIsolatedDefaults()
        let presenter = AutoPasteOnboardingPresenter(defaults: defaults)

        presenter.markSeen()

        #expect(presenter.hasBeenSeen)
        #expect(defaults.bool(forKey: AutoPasteOnboardingPresenter.userDefaultsKey))
    }

    @Test("presentIfNeeded is a no-op when already seen")
    func presentIfNeededRespectsSeenFlag() {
        let defaults = makeIsolatedDefaults()
        defaults.set(true, forKey: AutoPasteOnboardingPresenter.userDefaultsKey)
        let presenter = AutoPasteOnboardingPresenter(defaults: defaults)
        let paster = AutoPaster(trustCheck: { false })

        presenter.presentIfNeeded(autoPaster: paster)

        #expect(presenter.hasBeenSeen)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suite = "AutoPasteOnboardingPresenterTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
