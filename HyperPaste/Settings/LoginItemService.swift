import Foundation
import ServiceManagement

struct LoginItemService {
    private static let didAttemptDefaultRegistrationKey = "LoginItemService.didAttemptDefaultRegistration"

    private let service: SMAppService
    private let defaults: UserDefaults

    init(
        service: SMAppService = .mainApp,
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.defaults = defaults
    }

    var status: SMAppService.Status {
        service.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            return true
        } catch {
            NSLog("HyperPaste: failed to %@ login item: %@", enabled ? "register" : "unregister", String(describing: error))
            return false
        }
    }

    func enableByDefaultIfNeeded() {
        guard !defaults.bool(forKey: Self.didAttemptDefaultRegistrationKey) else { return }
        defaults.set(true, forKey: Self.didAttemptDefaultRegistrationKey)

        guard status != .enabled else { return }
        _ = setEnabled(true)
    }
}
