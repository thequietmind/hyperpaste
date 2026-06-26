import AppKit

struct PasteboardReader {
    func snapshot(of pasteboard: NSPasteboard) async -> PasteboardSnapshot {
        let types = Set(pasteboard.types ?? [])
        let string = pasteboard.string(forType: .string)
        let fileURLs = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL]
        let normalizedFileURLs: [URL]? = (fileURLs?.isEmpty == false) ? fileURLs : nil

        // Image: only when there are no file URLs (file copies often include image previews)
        let imageData: Data?
        if normalizedFileURLs == nil {
            imageData = readImage(from: pasteboard, types: types)
        } else {
            imageData = nil
        }

        var detected: Set<String> = []
        if string != nil, imageData == nil, normalizedFileURLs == nil {
            do {
                let patterns = try await pasteboard.detectedPatterns(
                    for: [\.links, \.emailAddresses, \.phoneNumbers, \.calendarEvents, \.postalAddresses]
                )
                detected = Self.kinds(from: patterns)
            } catch {
                // Best-effort; ignore
            }
        }

        return PasteboardSnapshot(
            types: types,
            string: string,
            imageData: imageData,
            fileURLs: normalizedFileURLs,
            detectedKinds: detected
        )
    }

    private func readImage(
        from pasteboard: NSPasteboard,
        types: Set<NSPasteboard.PasteboardType>
    ) -> Data? {
        let preferred: [NSPasteboard.PasteboardType] = [.png, .tiff]
        for type in preferred where types.contains(type) {
            guard let raw = pasteboard.data(forType: type) else { continue }
            if let normalized = ImageDimensions.normalizeToPNG(raw) {
                return normalized.pngData
            }
        }
        return nil
    }

    private static func kinds(
        from patterns: Set<PartialKeyPath<NSPasteboard.DetectedValues>>
    ) -> Set<String> {
        var result: Set<String> = []
        if patterns.contains(\.links) { result.insert("links") }
        if patterns.contains(\.emailAddresses) { result.insert("emailAddresses") }
        if patterns.contains(\.phoneNumbers) { result.insert("phoneNumbers") }
        if patterns.contains(\.calendarEvents) { result.insert("calendarEvents") }
        if patterns.contains(\.postalAddresses) { result.insert("postalAddresses") }
        return result
    }
}
