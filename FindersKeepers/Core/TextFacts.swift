import Foundation

/// The useful facts inside a screenshot's text: a place, links, and days still to come.
struct TextFacts: Equatable {
    var address = ""
    var links: [String] = []
    var dates: [Date] = []

    static let maxLinks = 5
    static let maxDates = 4

    /// Uses the system data detector, the same one that underlines dates and addresses in Messages.
    static func find(in text: String, now: Date = Date()) -> TextFacts {
        var facts = TextFacts()
        let wanted: NSTextCheckingResult.CheckingType = [.date, .address, .link]
        guard let detector = try? NSDataDetector(types: wanted.rawValue) else { return facts }

        let earliest = now.addingTimeInterval(-86_400)
        let latest = now.addingTimeInterval(2 * 365 * 86_400)

        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            let phrase = String(text[range])
            switch match.resultType {
            case .date:
                if let date = match.date, TextRules.namesADay(phrase),
                   date > earliest, date < latest, !facts.dates.contains(date) {
                    facts.dates.append(date)
                }
            case .address:
                if facts.address.isEmpty {
                    facts.address = phrase.split(whereSeparator: \.isNewline).joined(separator: ", ")
                }
            case .link:
                if let url = match.url, let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
                   !facts.links.contains(url.absoluteString), facts.links.count < maxLinks {
                    facts.links.append(url.absoluteString)
                }
            default:
                break
            }
        }
        facts.dates = Array(facts.dates.sorted().prefix(maxDates))
        return facts
    }
}
