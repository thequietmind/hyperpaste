import Foundation

struct ParsedColor: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

enum ColorParser {
    static func parse(_ raw: String) -> ParsedColor? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        if value.hasPrefix("#") {
            return parseHex(value)
        }

        let lower = value.lowercased()
        if lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(") {
            return parseRGBFunction(lower)
        }
        if lower.hasPrefix("hsl(") || lower.hasPrefix("hsla(") {
            return parseHSLFunction(lower)
        }

        return nil
    }

    private static func parseHex(_ value: String) -> ParsedColor? {
        let hex = String(value.dropFirst())
        guard [3, 4, 6, 8].contains(hex.count), hex.allSatisfy(\.isHexDigit) else {
            return nil
        }

        let expanded: String
        if hex.count == 3 || hex.count == 4 {
            expanded = hex.map { String(repeating: String($0), count: 2) }.joined()
        } else {
            expanded = hex
        }

        guard let red = byte(expanded, 0),
              let green = byte(expanded, 2),
              let blue = byte(expanded, 4)
        else { return nil }
        let alpha = byte(expanded, 6) ?? 255

        return ParsedColor(
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            alpha: Double(alpha) / 255
        )
    }

    private static func parseRGBFunction(_ value: String) -> ParsedColor? {
        guard let body = functionBody(value) else { return nil }
        let parsed = parseFunctionComponents(body, expectedComponentCount: 3)
        guard let components = parsed.components,
              components.count == 3,
              let red = parseByte(components[0]),
              let green = parseByte(components[1]),
              let blue = parseByte(components[2])
        else { return nil }

        let alpha: Double
        if let alphaValue = parsed.alpha {
            guard let parsedAlpha = parseAlpha(alphaValue) else { return nil }
            alpha = parsedAlpha
        } else {
            alpha = 1
        }
        return ParsedColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    private static func parseHSLFunction(_ value: String) -> ParsedColor? {
        guard let body = functionBody(value) else { return nil }
        let parsed = parseFunctionComponents(body, expectedComponentCount: 3)
        guard let components = parsed.components,
              components.count == 3,
              let hue = Double(components[0]),
              let saturation = parsePercent(components[1]),
              let lightness = parsePercent(components[2])
        else { return nil }

        let alpha: Double
        if let alphaValue = parsed.alpha {
            guard let parsedAlpha = parseAlpha(alphaValue) else { return nil }
            alpha = parsedAlpha
        } else {
            alpha = 1
        }
        let rgb = hslToRGB(hue: hue, saturation: saturation, lightness: lightness)
        return ParsedColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
    }

    private static func functionBody(_ value: String) -> String? {
        guard let open = value.firstIndex(of: "("), value.last == ")" else { return nil }
        return String(value[value.index(after: open)..<value.index(before: value.endIndex)])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseFunctionComponents(
        _ body: String,
        expectedComponentCount: Int
    ) -> (components: [String]?, alpha: String?) {
        if body.contains(",") {
            let parts = body.split(separator: ",", omittingEmptySubsequences: false)
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            guard parts.count == expectedComponentCount || parts.count == expectedComponentCount + 1 else {
                return (nil, nil)
            }
            return (Array(parts.prefix(expectedComponentCount)), parts.count == expectedComponentCount + 1 ? parts.last : nil)
        }

        let slashParts = body.split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        guard slashParts.count == 1 || slashParts.count == 2 else { return (nil, nil) }

        let components = slashParts[0].split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard components.count == expectedComponentCount else { return (nil, nil) }
        return (components, slashParts.count == 2 ? slashParts[1] : nil)
    }

    private static func byte(_ hex: String, _ offset: Int) -> Int? {
        guard offset + 2 <= hex.count else { return nil }
        let start = hex.index(hex.startIndex, offsetBy: offset)
        let end = hex.index(start, offsetBy: 2)
        return Int(hex[start..<end], radix: 16)
    }

    private static func parseByte(_ value: String) -> Double? {
        guard let byte = Int(value), (0...255).contains(byte) else { return nil }
        return Double(byte) / 255
    }

    private static func parsePercent(_ value: String) -> Double? {
        guard value.hasSuffix("%"),
              let percent = Double(value.dropLast()),
              (0...100).contains(percent)
        else { return nil }
        return percent / 100
    }

    private static func parseAlpha(_ value: String) -> Double? {
        if value.hasSuffix("%") {
            return parsePercent(value)
        }
        guard let alpha = Double(value), (0...1).contains(alpha) else { return nil }
        return alpha
    }

    private static func hslToRGB(
        hue: Double,
        saturation: Double,
        lightness: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let normalizedHue = ((hue.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360) / 360

        guard saturation > 0 else {
            return (lightness, lightness, lightness)
        }

        let q = lightness < 0.5
            ? lightness * (1 + saturation)
            : lightness + saturation - lightness * saturation
        let p = 2 * lightness - q

        return (
            hueChannel(p: p, q: q, t: normalizedHue + 1.0 / 3.0),
            hueChannel(p: p, q: q, t: normalizedHue),
            hueChannel(p: p, q: q, t: normalizedHue - 1.0 / 3.0)
        )
    }

    private static func hueChannel(p: Double, q: Double, t raw: Double) -> Double {
        var t = raw
        if t < 0 { t += 1 }
        if t > 1 { t -= 1 }
        if t < 1.0 / 6.0 { return p + (q - p) * 6 * t }
        if t < 1.0 / 2.0 { return q }
        if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6 }
        return p
    }
}
