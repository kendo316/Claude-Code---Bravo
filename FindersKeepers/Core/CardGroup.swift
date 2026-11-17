import Foundation

/// A shelf a screenshot can be filed on.
struct CardGroup: Identifiable, Hashable {
    let id: String
    let name: String
    /// Words that point to this group. Only used when the on-device model is unavailable.
    let hints: [String]

    static let other = CardGroup(id: "other", name: "Other", hints: [])

    static let all: [CardGroup] = [
        CardGroup(id: "eat", name: "Eat & drink", hints: ["restaurant", "menu", "reservation", "brewery", "cocktail", "coffee", "tacos", "happy hour"]),
        CardGroup(id: "cook", name: "Cook", hints: ["recipe", "ingredients", "tbsp", "tsp", "preheat", "simmer", "servings"]),
        CardGroup(id: "go", name: "Go & see", hints: ["tickets", "doors open", "trail", "museum", "festival", "venue", "admission", "itinerary"]),
        CardGroup(id: "listen", name: "Listen & watch", hints: ["album", "episode", "podcast", "playlist", "streaming", "trailer", "vinyl"]),
        CardGroup(id: "read", name: "Read", hints: ["chapter", "author", "article", "paperback", "min read", "newsletter"]),
        CardGroup(id: "house", name: "House & yard", hints: ["garden", "paint", "yard", "mulch", "perennial", "contractor", "sq ft"]),
        CardGroup(id: "buy", name: "Buy", hints: ["add to cart", "free shipping", "in stock", "checkout", "order placed", "price"]),
        CardGroup(id: "build", name: "Build", hints: ["github", "repository", "swift", "prompt", "app store", "xcode", "deploy"]),
        CardGroup(id: "work", name: "Work", hints: ["meeting", "client", "agenda", "portfolio", "treasurer", "yield", "district"]),
        CardGroup(id: "people", name: "People & laughs", hints: ["lol", "haha", "happy birthday", "delivered", "imessage"]),
        CardGroup(id: "ref", name: "Keep on file", hints: ["confirmation", "receipt", "account", "policy", "serial", "warranty", "order #"]),
        other,
    ]

    static func named(_ id: String) -> CardGroup {
        all.first { $0.id == id } ?? other
    }

    static func isKnown(_ id: String) -> Bool {
        all.contains { $0.id == id }
    }

    /// Picks the group whose hint words show up most often. Falls back to Other.
    static func guess(from text: String) -> CardGroup {
        let folded = text.foldedForSearch
        var best = other
        var bestHits = 0
        for group in all {
            let hits = group.hints.filter { folded.contains($0) }.count
            if hits > bestHits {
                best = group
                bestHits = hits
            }
        }
        return best
    }
}
