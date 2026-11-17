import Vision
import UIKit
import FoundationModels

struct Extracted {
    var title = ""
    var summary = ""
    var group = "other"
    var text = ""
    var address = ""
    var links: [String] = []
    var dates: [Date] = []
}

/// What Apple's on-device model fills in for each screenshot.
@Generable
struct SortResult {
    @Guide(description: "A short clear title, at most 7 words")
    var title: String
    @Guide(description: "One sentence: what this is and why someone might have saved it")
    var summary: String
    @Guide(description: "Exactly one category id from the list in the prompt, for example eat or build")
    var group: String
}

enum Reader {

    // MARK: Entry point

    static func read(_ cg: CGImage) async -> Extracted {
        let text = await ocr(cg)
        var e = detect(in: text)
        e.text = String(text.prefix(6000))

        if text.count > 12, let s = await smart(text) {
            e.title = s.title.trimmingCharacters(in: .whitespacesAndNewlines)
            e.summary = s.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            let g = s.group.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            e.group = Groups.all.contains { $0.id == g } ? g : guessGroup(text)
        }
        if e.title.isEmpty {
            e.title = firstUsefulLine(text) ?? "Screenshot"
            e.group = guessGroup(text)
        }
        return e
    }

    // MARK: OCR (Apple Vision, on device, free)

    static func ocr(_ cg: CGImage) async -> String {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .utility).async {
                let req = VNRecognizeTextRequest()
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cg)
                try? handler.perform([req])
                let lines = (req.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines.joined(separator: "\n"))
            }
        }
    }

    // MARK: Addresses, links, dates (Apple's data detector)

    static func detect(in text: String) -> Extracted {
        var e = Extracted()
        let types = NSTextCheckingResult.CheckingType.date.rawValue
            | NSTextCheckingResult.CheckingType.address.rawValue
            | NSTextCheckingResult.CheckingType.link.rawValue
        guard let det = try? NSDataDetector(types: types) else { return e }
        let now = Date()
        let limit = now.addingTimeInterval(86400 * 730)
        for m in det.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let r = Range(m.range, in: text) else { continue }
            let piece = String(text[r])
            switch m.resultType {
            case .date:
                if let d = m.date, looksLikeDate(piece),
                   d > now.addingTimeInterval(-86400), d < limit, !e.dates.contains(d) {
                    e.dates.append(d)
                }
            case .address:
                if e.address.isEmpty { e.address = piece.replacingOccurrences(of: "\n", with: ", ") }
            case .link:
                if let u = m.url?.absoluteString, u.hasPrefix("http"), !e.links.contains(u), e.links.count < 5 {
                    e.links.append(u)
                }
            default: break
            }
        }
        e.dates.sort()
        e.dates = Array(e.dates.prefix(4))
        return e
    }

    /// Skip bare times like "7:30 PM" that the detector turns into "today".
    private static func looksLikeDate(_ s: String) -> Bool {
        let l = s.lowercased()
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if months.contains(where: { l.contains($0) }) { return true }
        return l.range(of: #"\d{1,2}[/\-.]\d{1,2}"#, options: .regularExpression) != nil
    }

    // MARK: Smart title and group (Apple Intelligence, on device)

    static func smart(_ text: String) async -> SortResult? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        let session = LanguageModelSession(instructions:
            "You file screenshots for one person. Given the text found in a screenshot, give it a short title, a one-sentence summary and exactly one category id.")
        let prompt = "Categories: \(Groups.promptList)\n\nText found in the screenshot:\n\(String(text.prefix(2400)))"
        return try? await session.respond(to: prompt, generating: SortResult.self).content
    }

    // MARK: Ask your collection (on device)

    static func ask(_ question: String, cards: [Card]) async -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            return "Apple Intelligence isn't available on this phone right now. Search still works."
        }
        if cards.isEmpty { return "Nothing in your pile matches that yet." }
        let lines = cards.map { c in
            "- \(c.title). \(c.summary) \(String(c.text.prefix(300)).replacingOccurrences(of: "\n", with: " "))"
        }.joined(separator: "\n")
        let session = LanguageModelSession(instructions:
            "Answer the question using only the saved screenshots listed. Be brief. If they don't answer it, say so.")
        let r = try? await session.respond(to: "Saved screenshots:\n\(lines)\n\nQuestion: \(question)")
        return r?.content ?? "I couldn't answer that one."
    }

    // MARK: Fallbacks when the model isn't available

    static func firstUsefulLine(_ text: String) -> String? {
        for raw in text.split(separator: "\n") {
            let s = raw.trimmingCharacters(in: .whitespaces)
            if s.count >= 5, s.rangeOfCharacter(from: .letters) != nil, s.range(of: #"^\d{1,2}:\d{2}"#, options: .regularExpression) == nil {
                return String(s.prefix(60))
            }
        }
        return nil
    }

    static func guessGroup(_ text: String) -> String {
        let t = text.lowercased()
        let rules: [(String, [String])] = [
            ("eat", ["restaurant", "menu", "reservation", "brewery", "cocktail", "coffee", "bar "]),
            ("cook", ["recipe", "ingredients", "tbsp", "tsp", "preheat", "bake"]),
            ("go", ["tickets", "hours", "open daily", "trail", "museum", "festival", "venue"]),
            ("listen", ["album", "episode", "podcast", "playlist", "streaming", "season"]),
            ("buy", ["add to cart", "$", "price", "sale", "free shipping"]),
            ("build", ["github", "api", "code", "app", "swift", "prompt"]),
            ("work", ["meeting", "client", "invoice", "quarter", "agenda"]),
            ("house", ["garden", "paint", "yard", "kitchen", "plant"]),
            ("read", ["chapter", "author", "article", "book"]),
        ]
        for (id, words) in rules where words.contains(where: { t.contains($0) }) { return id }
        return "other"
    }
}
