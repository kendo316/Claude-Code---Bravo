import Foundation

/// Small text rules that need no model: titles, search, and ranking for Ask.
enum TextRules {

    /// The first line that reads like a headline, skipping status-bar noise such as "9:41" or "5G".
    static func title(from text: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let candidate = line.trimmingCharacters(in: .whitespaces)
            let letters = candidate.filter(\.isLetter).count
            let startsWithClock = candidate.range(of: #"^\d{1,2}:\d{2}"#, options: .regularExpression) != nil
            if candidate.count >= 5, letters >= 4, !startsWithClock {
                return String(candidate.prefix(60))
            }
        }
        return nil
    }

    /// True only for a real calendar day: "Dec 4", "Friday, December 4" or "12/4/2026".
    /// A bare clock time ("7:30 PM"), a lone weekday ("open Tuesday to Sunday") and a fraction
    /// ("1/2 cup") are all things the system date detector will happily call a date. None of them
    /// is worth a reminder, so they are turned away here.
    static func namesADay(_ phrase: String) -> Bool {
        let folded = phrase.foldedForSearch
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if months.contains(where: { folded.contains($0) }) { return true }
        return folded.range(of: #"\b\d{1,2}[/.-]\d{1,2}[/.-]\d{2,4}\b"#, options: .regularExpression) != nil
    }

    /// True when the phrase spells out its year, as in "December 4, 2026" or "12/4/26".
    static func statesItsYear(_ phrase: String) -> Bool {
        phrase.range(of: #"\b(19|20)\d{2}\b|\b\d{1,2}[/.-]\d{1,2}[/.-]\d{2}\b"#, options: .regularExpression) != nil
    }

    /// Splits what was typed into the search field into words to look for.
    static func tokens(_ query: String) -> [String] {
        query.foldedForSearch.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Every word must appear somewhere in the card.
    static func matches(_ searchText: String, _ tokens: [String]) -> Bool {
        tokens.allSatisfy { searchText.contains($0) }
    }

    /// The cards most likely to answer a question: those sharing the most meaningful words with it.
    static func rank(question: String, searchTextByID: [String: String], limit: Int) -> [String] {
        let words = Set(tokens(question).filter { $0.count > 2 && !fillerWords.contains($0) })
        guard !words.isEmpty else { return [] }
        return searchTextByID
            .map { entry in (id: entry.key, score: words.filter { entry.value.contains($0) }.count) }
            .filter { $0.score > 0 }
            .sorted { ($0.score, $0.id) > ($1.score, $1.id) }
            .prefix(limit)
            .map(\.id)
    }

    private static let fillerWords: Set<String> = [
        "the", "and", "was", "what", "where", "when", "which", "that", "this", "with", "from",
        "for", "did", "does", "have", "had", "are", "you", "who", "how", "about", "there", "screenshot",
    ]
}
