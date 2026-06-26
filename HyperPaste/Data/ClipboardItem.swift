import Foundation
import SwiftData

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var kind: ItemKind
    var contentHash: String
    var groupKey: String
    var pinnedAt: Date?
    var sourceBundleIdentifier: String?
    var sourceAppName: String?
    var text: String?
    var imagePath: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var fileBookmarks: [Data]?
    var fileNames: [String]?
    var previewText: String
    var searchableText: String
    var detectedKinds: [String]

    init(
        id: UUID = UUID(),
        createdAt: Date,
        kind: ItemKind,
        contentHash: String,
        groupKey: String,
        text: String? = nil,
        imagePath: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        fileBookmarks: [Data]? = nil,
        fileNames: [String]? = nil,
        previewText: String,
        searchableText: String,
        detectedKinds: [String],
        sourceBundleIdentifier: String?,
        sourceAppName: String?,
        pinnedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.kind = kind
        self.contentHash = contentHash
        self.groupKey = groupKey
        self.text = text
        self.imagePath = imagePath
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.fileBookmarks = fileBookmarks
        self.fileNames = fileNames
        self.previewText = previewText
        self.searchableText = searchableText
        self.detectedKinds = detectedKinds
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceAppName = sourceAppName
        self.pinnedAt = pinnedAt
    }
}
