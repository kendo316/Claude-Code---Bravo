import Foundation

/// Decides which screenshots are due for the weekly look.
struct ReviewRules: Equatable {
    var batchSize = 25
    /// Days until a kept screenshot comes back around. 0 means never.
    var resurfaceAfterDays = 180

    /// "Next week" hides a screenshot for six days, not seven,
    /// so it is back in time for a look on the same weekday a little earlier in the day.
    static let snoozeDays = 6

    /// A screenshot is due when it was never decided, when its "next week" has run out,
    /// or when it was kept long enough ago to come back around.
    func isDue(_ card: Card?, now: Date) -> Bool {
        guard let card else { return true }
        if let snoozedAt = card.snoozedAt, now.timeIntervalSince(snoozedAt) < Self.seconds(days: Self.snoozeDays) {
            return false
        }
        guard let keptAt = card.keptAt else { return true }
        guard resurfaceAfterDays > 0 else { return false }
        return now.timeIntervalSince(keptAt) > Self.seconds(days: resurfaceAfterDays)
    }

    /// Every due screenshot, in the order given (the app passes oldest first).
    func dueIDs(in ids: [String], cards: [String: Card], excluding: Set<String>, now: Date) -> [String] {
        ids.filter { !excluding.contains($0) && isDue(cards[$0], now: now) }
    }

    /// This week's batch: the first `batchSize` due screenshots.
    func batch(in ids: [String], cards: [String: Card], excluding: Set<String>, now: Date) -> [String] {
        Array(dueIDs(in: ids, cards: cards, excluding: excluding, now: now).prefix(batchSize))
    }

    private static func seconds(days: Int) -> TimeInterval {
        TimeInterval(days) * 86_400
    }
}
