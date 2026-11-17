import Foundation

/// The useful facts inside a screenshot's text: a place, links, and days still to come.
struct TextFacts: Equatable {
    var address = ""
    var links: [String] = []
    var dates: [Date] = []

    static let maxLinks = 5
    static let maxDates = 4

    /// Uses the system data detector, the same one that underlines dates and addresses in Messages.
    /// `captured` is when the screenshot was taken. "December 4" in a screenshot from 2021 meant 2021,
    /// so days are worked out from then, and only the ones still ahead of `now` are kept.
    static func find(in text: String, captured: Date, now: Date = Date()) -> TextFacts {
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
                guard let detected = match.date, TextRules.namesADay(phrase) else { continue }
                let date = TextRules.statesItsYear(phrase) ? detected : firstOccurrence(of: detected, onOrAfter: captured)
                if date > earliest, date < latest, !facts.dates.contains(date) {
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

    /// The detector guesses the year from today. This takes its month, day and time
    /// and finds the first such day on or after the screenshot was taken.
    private static func firstOccurrence(of detected: Date, onOrAfter captured: Date) -> Date {
        let calendar = Calendar.current
        let wanted = calendar.dateComponents([.month, .day, .hour, .minute], from: detected)
        let dayBefore = calendar.startOfDay(for: captured).addingTimeInterval(-1)
        return calendar.nextDate(after: dayBefore, matching: wanted, matchingPolicy: .nextTime) ?? detected
    }
}
