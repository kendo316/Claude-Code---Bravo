import SwiftUI

// MARK: - Theme (same palette as the web version)

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255,
                  blue: Double(hex & 255) / 255)
    }
    static let wall = Color(hex: 0x13203b)
    static let gold = Color(hex: 0xf6a821)
    static let paper = Color(hex: 0xf2ede2)
}

// MARK: - Groups

struct Grp: Identifiable, Hashable {
    let id: String
    let name: String
}

enum Groups {
    static let all: [Grp] = [
        Grp(id: "eat", name: "Eat & drink"),
        Grp(id: "cook", name: "Cook"),
        Grp(id: "go", name: "Go & see"),
        Grp(id: "listen", name: "Listen & watch"),
        Grp(id: "read", name: "Read"),
        Grp(id: "house", name: "House & yard"),
        Grp(id: "buy", name: "Buy"),
        Grp(id: "build", name: "Build"),
        Grp(id: "work", name: "Work"),
        Grp(id: "people", name: "People & laughs"),
        Grp(id: "ref", name: "Keep on file"),
        Grp(id: "other", name: "Other"),
    ]

    static func name(_ id: String) -> String {
        all.first { $0.id == id }?.name ?? "Other"
    }

    static var promptList: String {
        all.map { "\($0.id) = \($0.name)" }.joined(separator: "; ")
    }
}

// MARK: - Card (what we remember about one screenshot)

struct Card: Codable, Identifiable, Hashable {
    var id: String                 // PHAsset.localIdentifier
    var title: String = ""
    var summary: String = ""
    var group: String = "other"
    var text: String = ""          // everything OCR found
    var address: String = ""
    var links: [String] = []
    var dates: [Date] = []
    var note: String = ""
    var read: Bool = false
    var decidedAt: Date?           // last "Keep as new"
    var snoozedAt: Date?           // last "Next week"
    var snoozes: Int = 0

    var haystack: String {
        [title, summary, Groups.name(group), text, address, note, links.joined(separator: " ")]
            .joined(separator: " ").lowercased()
    }
}

struct Saved: Codable {
    var cards: [String: Card]
    var pending: [String]
    var lastReview: Date?
}
