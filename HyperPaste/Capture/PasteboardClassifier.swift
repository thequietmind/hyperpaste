import Foundation

struct PasteboardClassifier {
    var excludedBundleIDs: Set<String>

    init(excludedBundleIDs: Set<String> = ExcludedApps.defaultBundleIDs) {
        self.excludedBundleIDs = excludedBundleIDs
    }

    func classify(
        snapshot: PasteboardSnapshot,
        sourceBundleID: String?
    ) -> ClassificationResult {
        if let reason = snapshot.sensitiveTypeReason {
            return .skipped(reason)
        }

        if let bundleID = sourceBundleID, excludedBundleIDs.contains(bundleID) {
            return .skipped(.excludedApp(bundleID: bundleID))
        }

        if let urls = snapshot.fileURLs, !urls.isEmpty {
            return classifyFiles(urls)
        }

        if let pngData = snapshot.imageData, !pngData.isEmpty {
            return classifyImage(pngData: pngData)
        }

        if let raw = snapshot.string, !raw.isEmpty {
            return classifyText(raw, detectedKinds: snapshot.detectedKinds)
        }

        return .skipped(.noSupportedContent)
    }

    // MARK: - Per-kind classification

    private func classifyText(_ raw: String, detectedKinds: Set<String>) -> ClassificationResult {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return .skipped(.noSupportedContent)
        }

        let kind: ItemKind
        if detectedKinds.contains("links") {
            kind = .link
        } else if ColorParser.parse(normalized) != nil {
            kind = .color
        } else if CodeHeuristic.looksLikeCode(raw) {
            kind = .code
        } else {
            kind = .text
        }

        let item = ClassifiedItem(
            kind: kind,
            payload: .text(raw),
            previewText: PreviewBuilder.singleLine(raw),
            searchableText: SearchableTextBuilder.build(raw),
            contentHash: ContentHasher.sha256Hex(normalized),
            detectedKinds: detectedKinds.sorted()
        )
        return .classified(item)
    }

    private func classifyImage(pngData: Data) -> ClassificationResult {
        let dims = ImageDimensions.read(from: pngData)
        let preview: String
        if let dims {
            preview = "\(dims.width) × \(dims.height)"
        } else {
            preview = "Image"
        }
        let item = ClassifiedItem(
            kind: .image,
            payload: .image(pngData: pngData, width: dims?.width ?? 0, height: dims?.height ?? 0),
            previewText: preview,
            searchableText: "",
            contentHash: ContentHasher.sha256Hex(pngData),
            detectedKinds: []
        )
        return .classified(item)
    }

    private func classifyFiles(_ urls: [URL]) -> ClassificationResult {
        let names = urls.map { $0.lastPathComponent }
        let preview: String
        if names.count == 1 {
            preview = names[0]
        } else if let first = names.first {
            preview = "\(first) + \(names.count - 1) more"
        } else {
            preview = "Files"
        }
        let joinedPaths = urls.map { $0.path }.joined(separator: "\n")
        let item = ClassifiedItem(
            kind: .files,
            payload: .files(urls: urls, names: names),
            previewText: preview,
            searchableText: names.joined(separator: " ").lowercased(),
            contentHash: ContentHasher.sha256Hex(joinedPaths),
            detectedKinds: []
        )
        return .classified(item)
    }
}
