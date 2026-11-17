import XCTest
@testable import FKCore

final class ReviewRulesTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func daysAgo(_ days: Double) -> Date { now.addingTimeInterval(-days * 86_400) }

    func testNeverSeenIsDue() {
        XCTAssertTrue(ReviewRules().isDue(nil, now: now))
        XCTAssertTrue(ReviewRules().isDue(Card(id: "a"), now: now))
    }

    func testNextWeekHidesForSixDaysThenReturns() {
        var card = Card(id: "a")
        card.snoozedAt = daysAgo(5.9)
        XCTAssertFalse(ReviewRules().isDue(card, now: now))
        card.snoozedAt = daysAgo(6.1)
        XCTAssertTrue(ReviewRules().isDue(card, now: now))
    }

    func testSameWeekdayALittleEarlierStillBringsItBack() {
        // Snoozed Sunday at 7:30 pm, next look Sunday at 7:00 pm.
        var card = Card(id: "a")
        card.snoozedAt = now.addingTimeInterval(-(7 * 86_400 - 1_800))
        XCTAssertTrue(ReviewRules().isDue(card, now: now))
    }

    func testKeptComesBackOnlyAfterTheResurfaceWindow() {
        var card = Card(id: "a")
        card.keptAt = daysAgo(179)
        XCTAssertFalse(ReviewRules().isDue(card, now: now))
        card.keptAt = daysAgo(181)
        XCTAssertTrue(ReviewRules().isDue(card, now: now))
    }

    func testKeptNeverComesBackWhenResurfaceIsOff() {
        var card = Card(id: "a")
        card.keptAt = daysAgo(5_000)
        XCTAssertFalse(ReviewRules(batchSize: 25, resurfaceAfterDays: 0).isDue(card, now: now))
    }

    func testResurfacedThenSnoozedWaitsAgain() {
        var card = Card(id: "a")
        card.keptAt = daysAgo(400)
        card.snoozedAt = daysAgo(1)
        XCTAssertFalse(ReviewRules().isDue(card, now: now))
    }

    func testBatchKeepsOrderSkipsMarkedAndStopsAtBatchSize() {
        let ids = (1...40).map { "s\($0)" }
        var kept = Card(id: "s2")
        kept.keptAt = daysAgo(1)
        let rules = ReviewRules(batchSize: 25, resurfaceAfterDays: 180)
        let batch = rules.batch(in: ids, cards: ["s2": kept], excluding: ["s1"], now: now)
        XCTAssertEqual(batch.count, 25)
        XCTAssertEqual(batch.first, "s3")
        XCTAssertFalse(batch.contains("s1"))
        XCTAssertFalse(batch.contains("s2"))
        XCTAssertEqual(rules.dueIDs(in: ids, cards: ["s2": kept], excluding: ["s1"], now: now).count, 38)
    }
}
