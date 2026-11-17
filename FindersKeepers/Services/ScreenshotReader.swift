import Photos
import Vision

/// What reading one screenshot produces.
struct Reading {
    var title = ""
    var summary = ""
    var group = CardGroup.other.id
    var text = ""
    var facts = TextFacts()
}

/// Reads a screenshot entirely on the phone: Apple Vision finds the words,
/// the system data detector finds dates, places and links, and the on-device model writes a title.
enum ScreenshotReader {
    /// Enough for search without letting one long screenshot bloat the saved file.
    static let maxStoredCharacters = 6_000

    /// Returns nil when Photos cannot supply the image, so it can be tried again later.
    static func read(_ asset: PHAsset) async -> Reading? {
        guard let image = await PhotoLibrary.fullSizeImage(for: asset) else { return nil }
        let text = await recognizeText(in: image)

        var reading = Reading()
        reading.text = String(text.prefix(maxStoredCharacters))
        reading.facts = TextFacts.find(in: text)

        if let filing = await OnDeviceModel.file(text) {
            reading.title = filing.title
            reading.summary = filing.summary
            reading.group = filing.group
        } else {
            reading.title = TextRules.title(from: text) ?? ""
            reading.group = CardGroup.guess(from: text).id
        }
        return reading
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
