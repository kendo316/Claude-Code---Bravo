import Photos
import Vision

/// What the first, fast pass over a screenshot produces.
struct Reading {
    var text = ""
    var facts = TextFacts()
    /// A plain-rules title and group, used until the on-device model writes better ones.
    var title = ""
    var group = CardGroup.other.id
}

/// Reads a screenshot entirely on the phone: Apple Vision finds the words,
/// and the system data detector finds dates, places and links.
enum ScreenshotReader {
    /// Enough for search without letting one long screenshot bloat the saved file.
    static let maxStoredCharacters = 6_000

    /// Returns nil when Photos cannot supply the image, so it can be tried again later.
    static func read(_ asset: PHAsset) async -> Reading? {
        guard let image = await PhotoLibrary.fullSizeImage(for: asset) else { return nil }
        let text = await recognizeText(in: image)
        return Reading(
            text: String(text.prefix(maxStoredCharacters)),
            facts: TextFacts.find(in: text, captured: asset.creationDate ?? Date()),
            title: TextRules.title(from: text) ?? "",
            group: CardGroup.guess(from: text).id
        )
    }

    private static func recognizeText(in image: CGImage) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                try? VNImageRequestHandler(cgImage: image).perform([request])
                let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }
}
