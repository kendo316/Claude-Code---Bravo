import XCTest
@testable import FKCore

final class TextTests: XCTestCase {
    func testTitleSkipsStatusBarNoise() {
        let text = "9:41\n5G\n100%\nPujol tasting menu\nReserve a table"
        XCTAssertEqual(TextRules.title(from: text), "Pujol tasting menu")
        XCTAssertNil(TextRules.title(from: "9:41\n5G\n88"))
    }

    func testOnlyRealCalendarDaysCount() {
        XCTAssertTrue(TextRules.namesADay("Dec 4 at 7:30 PM"))
        XCTAssertTrue(TextRules.namesADay("Friday, December 4"))
        XCTAssertTrue(TextRules.namesADay("12/4/2026"))
        XCTAssertFalse(TextRules.namesADay("7:30 PM"))
        XCTAssertFalse(TextRules.namesADay("Tuesday 11:00 AM"))
        XCTAssertFalse(TextRules.namesADay("1/2"))
        XCTAssertFalse(TextRules.namesADay("5.5"))
        XCTAssertTrue(TextRules.statesItsYear("December 4, 2026"))
        XCTAssertTrue(TextRules.statesItsYear("12/4/26"))
        XCTAssertFalse(TextRules.statesItsYear("December 4 at 8:00 PM"))
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testDayWithoutAYearIsReadFromWhenTheScreenshotWasTaken() {
        let text = "Night Owls Quartet\nFriday, December 4 at 8:00 PM"
        // Taken a month before the show: still ahead, so it is kept, in the right year.
        let fresh = TextFacts.find(in: text, captured: day(2030, 11, 1), now: day(2030, 11, 2))
        XCTAssertEqual(fresh.dates.count, 1)
        if let date = fresh.dates.first {
            let found = Calendar.current.dateComponents([.year, .month, .day, .hour], from: date)
            XCTAssertEqual([found.year, found.month, found.day, found.hour], [2030, 12, 4, 20])
        }
        // The same screenshot found years later: that show is long over, so no reminder.
        let stale = TextFacts.find(in: text, captured: day(2021, 11, 1), now: day(2030, 11, 2))
        XCTAssertTrue(stale.dates.isEmpty)
    }

    func testOpeningHoursAndFractionsAreNotReminders() {
        let text = "Open Tuesday to Sunday\n11:00 AM to 9:00 PM\n1/2 cup butter\nlol bring it Saturday"
        XCTAssertTrue(TextFacts.find(in: text, captured: Date(), now: Date()).dates.isEmpty)
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
        let text = "Night Owls Quartet\nDecember 4, 2030 at 8:00 PM\nTickets: https://example.com/tickets\nDoors 7:00 PM\nmailto:someone@example.com"
        let facts = TextFacts.find(in: text, captured: now, now: now)
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
        XCTAssertTrue(TextFacts.find(in: "December 4, 2030 at 8:00 PM", captured: now, now: now).dates.isEmpty)
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
