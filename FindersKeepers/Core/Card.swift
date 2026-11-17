import Foundation

/// Everything the app remembers about one screenshot.
/// The image itself never leaves Photos; `id` is the Photos identifier that points back to it.
struct Card: Codable, Identifiable, Equatable {
    let id: String
    var title = ""
    var summary = ""
    var group = CardGroup.other.id
    /// Words found in the image. This is what makes search reach inside screenshots.
    var text = ""
    var address = ""
    var links: [String] = []
    var dates: [Date] = []
    var note = ""
    var isRead = false
    /// True once the title or group was changed by hand, so a re-read leaves them alone.
    var isEdited = false
    /// The last time "Keep" was chosen. Nil means it has never been decided.
    var keptAt: Date?
    /// The last time "Next week" was chosen.
    var snoozedAt: Date?
    var snoozeCount = 0

    init(id: String) {
        self.id = id
    }

    /// Missing fields fall back to their defaults, so a file saved by an older version still loads.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        title = values.value(.title, or: "")
        summary = values.value(.summary, or: "")
        group = values.value(.group, or: CardGroup.other.id)
        text = values.value(.text, or: "")
        address = values.value(.address, or: "")
        links = values.value(.links, or: [])
        dates = values.value(.dates, or: [])
        note = values.value(.note, or: "")
        isRead = values.value(.isRead, or: false)
        isEdited = values.value(.isEdited, or: false)
        keptAt = try? values.decodeIfPresent(Date.self, forKey: .keptAt)
        snoozedAt = try? values.decodeIfPresent(Date.self, forKey: .snoozedAt)
        snoozeCount = values.value(.snoozeCount, or: 0)
    }

    /// One folded string holding everything search should match against.
    var searchText: String {
        [title, summary, CardGroup.named(group).name, note, address, text]
            .joined(separator: "\n")
            .foldedForSearch
    }
}

extension KeyedDecodingContainer {
    /// Decodes a value, or returns `fallback` when the key is missing or holds the wrong type.
    func value<T: Decodable>(_ key: Key, or fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }
}

extension String {
    /// Lowercased with accents removed, so "cafe" finds "Café".
    var foldedForSearch: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
