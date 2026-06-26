import SwiftUI

private struct AttachmentStoreKey: EnvironmentKey {
    static let defaultValue: AttachmentStore? = nil
}

extension EnvironmentValues {
    var attachmentStore: AttachmentStore? {
        get { self[AttachmentStoreKey.self] }
        set { self[AttachmentStoreKey.self] = newValue }
    }
}
