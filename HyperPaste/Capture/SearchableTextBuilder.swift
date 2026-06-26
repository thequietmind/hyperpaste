import Foundation

enum SearchableTextBuilder {
    static func build(_ string: String, maxChars: Int = 4096) -> String {
        let lower = string.lowercased()
        if lower.count <= maxChars { return lower }
        return String(lower.prefix(maxChars))
    }
}
