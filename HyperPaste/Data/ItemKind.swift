import Foundation

enum ItemKind: String, Codable, CaseIterable, Sendable {
    case text
    case link
    case code
    case color
    case image
    case files
}
