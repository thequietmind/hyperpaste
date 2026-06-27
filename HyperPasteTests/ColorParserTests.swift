import Testing
@testable import HyperPaste

@Suite("ColorParser")
struct ColorParserTests {
    @Test("parses supported hex formats")
    func parsesHexFormats() throws {
        let short = try #require(ColorParser.parse("#F00"))
        #expect(isClose(short.red, 1))
        #expect(isClose(short.green, 0))
        #expect(isClose(short.blue, 0))
        #expect(isClose(short.alpha, 1))

        let longWithAlpha = try #require(ColorParser.parse("#33669980"))
        #expect(isClose(longWithAlpha.red, 0.2))
        #expect(isClose(longWithAlpha.green, 0.4))
        #expect(isClose(longWithAlpha.blue, 0.6))
        #expect(isClose(longWithAlpha.alpha, 128.0 / 255.0))
    }

    @Test("parses comma and space separated rgb formats")
    func parsesRGBFormats() throws {
        let comma = try #require(ColorParser.parse("rgb(255, 0, 0)"))
        #expect(isClose(comma.red, 1))
        #expect(isClose(comma.green, 0))
        #expect(isClose(comma.blue, 0))
        #expect(isClose(comma.alpha, 1))

        let space = try #require(ColorParser.parse("rgb(0 128 255)"))
        #expect(isClose(space.red, 0))
        #expect(isClose(space.green, 128.0 / 255.0))
        #expect(isClose(space.blue, 1))
    }

    @Test("parses rgba alpha values")
    func parsesRGBAAlpha() throws {
        let decimal = try #require(ColorParser.parse("rgba(255, 0, 0, .5)"))
        #expect(isClose(decimal.alpha, 0.5))

        let percent = try #require(ColorParser.parse("rgba(255 0 0 / 50%)"))
        #expect(isClose(percent.alpha, 0.5))
    }

    @Test("parses hsl colors")
    func parsesHSL() throws {
        let green = try #require(ColorParser.parse("hsl(120,50%,50%)"))
        #expect(isClose(green.red, 0.25))
        #expect(isClose(green.green, 0.75))
        #expect(isClose(green.blue, 0.25))
        #expect(isClose(green.alpha, 1))

        let transparent = try #require(ColorParser.parse("hsla(120 50% 50% / 25%)"))
        #expect(isClose(transparent.alpha, 0.25))
    }

    @Test("ignores malformed or unsupported values")
    func ignoresMalformedValues() {
        #expect(ColorParser.parse("#12") == nil)
        #expect(ColorParser.parse("rgb(255, 0)") == nil)
        #expect(ColorParser.parse("rgb(300, 0, 0)") == nil)
        #expect(ColorParser.parse("hsl(120, 50, 50%)") == nil)
        #expect(ColorParser.parse("lab(50% 0 0)") == nil)
    }

    private func isClose(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 0.001
    }
}
