import Foundation

enum CodeHeuristic {
    private static let keywordPatterns: [String] = [
        "function ",
        "func ",
        "def ",
        "class ",
        "import ",
        "return ",
        "console.log",
        "print(",
        " => ",
        "let ",
        "var ",
        "const "
    ]

    static func looksLikeCode(_ string: String) -> Bool {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }

        if trimmed.contains("{") && trimmed.contains("}") {
            return true
        }

        let lower = trimmed.lowercased()
        for pattern in keywordPatterns where lower.contains(pattern) {
            return true
        }

        let lines = trimmed.split(whereSeparator: \.isNewline)
        let semicolonTerminated = lines.filter { line in
            line.trimmingCharacters(in: .whitespaces).hasSuffix(";")
        }
        if semicolonTerminated.count >= 2 {
            return true
        }

        return false
    }
}
