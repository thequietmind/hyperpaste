import Foundation

struct AttachmentStore: Sendable {
    let rootURL: URL

    init(rootURL: URL) throws {
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        self.rootURL = rootURL
    }

    init() throws {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = appSupport.appendingPathComponent("HyperPaste/Attachments", isDirectory: true)
        try self.init(rootURL: root)
    }

    @discardableResult
    func write(pngData: Data, id: UUID) throws -> String {
        let relativePath = "\(id.uuidString).png"
        let url = rootURL.appendingPathComponent(relativePath)
        try pngData.write(to: url, options: .atomic)
        return relativePath
    }

    func data(forRelativePath relativePath: String) -> Data? {
        let url = rootURL.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }

    func delete(relativePath: String) {
        let url = rootURL.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }
}
