import XCTest
@testable import FKCore

final class TextTests: XCTestCase {
    func testTitleSkipsStatusBarNoise() {
        let text = "9:41\n5G\n100%\nPujol tasting menu\nReserve a table"
        XCTAssertEqual(TextRules.title(from: text), "Pujol tasting menu")
        XCTAssertNil(TextRules.title(from: "9:41\n5G\n88"))
    }

    func testBareClockTimeIsNotADay() {
        XCTAssertFalse(TextRules.namesADay("7:30 PM"))
        XCTAssertTrue(TextRules.namesADay("Dec 4 at 7:30 PM"))
        XCTAssertTrue(TextRules.namesADay("12/4"))
        XCTAssertTrue(TextRules.namesADay("Friday"))
    }

    func testRankPrefersCardsSharingMoreWords() {
        let cards = ["a": "taco place on broadway", "b": "taco recipe", "c": "garden mulch"]
        XCTAssertEqual(TextRules.rank(question: "Where was that taco place?", searchTextByID: cards, limit: 5), ["a", "b"])
        XCTAssertEqual(TextRules.rank(question: "the and what", searchTextByID: cards, limit: 5), [])
    }

    func testGuessGroup() {
        XCTAssertEqual(CardGroup.guess(from: "Ingredients: 2 tbsp butter. Preheat oven.").id, "cook")
        XCTAssertEqual(CardGroup.guess(from: "nothing useful here").id, "other")
        XCTAssertTrue(CardGroup.isKnown("eat"))
        XCTAssertFalse(CardGroup.isKnown("nope"))
        XCTAssertEqual(CardGroup.named("nope"), CardGroup.other)
    }

    func testFactsFindLinkAndUpcomingDay() {
        var parts = DateComponents()
        parts.year = 2030; parts.month = 11; parts.day = 1; parts.hour = 12
        let now = Calendar.current.date(from: parts)!
        let text = "Andrew Bird\nDecember 4, 2030 at 8:00 PM\nTickets: https://example.com/tickets\nDoors 7:00 PM\nmailto:someone@example.com"
        let facts = TextFacts.find(in: text, now: now)
        XCTAssertEqual(facts.links, ["https://example.com/tickets"])
        XCTAssertEqual(facts.dates.count, 1)
        if let date = facts.dates.first {
            let found = Calendar.current.dateComponents([.year, .month, .day], from: date)
            XCTAssertEqual([found.year, found.month, found.day], [2030, 12, 4])
        }
    }

    func testFactsDropDaysAlreadyPast() {
        var parts = DateComponents()
        parts.year = 2031; parts.month = 6; parts.day = 1
        let now = Calendar.current.date(from: parts)!
        XCTAssertTrue(TextFacts.find(in: "December 4, 2030 at 8:00 PM", now: now).dates.isEmpty)
    }

    func testSignOffs() {
        XCTAssertEqual(SignOff.line(kept: 0, deleted: 0, later: 0), "Nothing decided. The pile will wait.")
        XCTAssertEqual(SignOff.line(kept: 0, deleted: 0, later: 25), "Kicked the whole can down the road. Bold.")
        XCTAssertEqual(SignOff.line(kept: 0, deleted: 25, later: 0), "Scorched earth. Respect.")
        XCTAssertEqual(SignOff.line(kept: 5, deleted: 20, later: 0), "Clean sweep. No maybes.")
        XCTAssertEqual(SignOff.line(kept: 5, deleted: 10, later: 10), "Lighter pile, clearer head.")
        XCTAssertNil(SignOff.snoozeNote(count: 0))
        XCTAssertEqual(SignOff.snoozeNote(count: 3), "put off 3×. Be honest.")
    }
}
