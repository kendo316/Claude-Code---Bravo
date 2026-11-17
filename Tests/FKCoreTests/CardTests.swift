import XCTest
@testable import FKCore

final class CardTests: XCTestCase {
    func testOldFileWithMissingFieldsStillLoads() throws {
        let json = #"{"id":"abc","title":"Taco place"}"#.data(using: .utf8)!
        let card = try JSONDecoder().decode(Card.self, from: json)
        XCTAssertEqual(card.id, "abc")
        XCTAssertEqual(card.title, "Taco place")
        XCTAssertEqual(card.group, "other")
        XCTAssertFalse(card.isRead)
        XCTAssertFalse(card.isTitled)
        XCTAssertNil(card.keptAt)
    }

    func testWrongTypeFallsBackInsteadOfFailing() throws {
        let json = #"{"id":"abc","snoozeCount":"three","links":7}"#.data(using: .utf8)!
        let card = try JSONDecoder().decode(Card.self, from: json)
        XCTAssertEqual(card.snoozeCount, 0)
        XCTAssertEqual(card.links, [])
    }

    func testSavedStateRoundTrips() throws {
        var card = Card(id: "abc")
        card.title = "Café Poca"
        card.dates = [Date(timeIntervalSince1970: 1_800_000_000)]
        card.keptAt = Date(timeIntervalSince1970: 1_799_000_000)
        var state = SavedState()
        state.cards = [card]
        state.markedForDelete = ["zzz"]
        state.looksCompleted = 4
        state.settings.batchSize = 10
        let copy = try JSONDecoder().decode(SavedState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(copy, state)
    }

    func testEmptyFileContentsGiveDefaults() throws {
        let state = try JSONDecoder().decode(SavedState.self, from: Data("{}".utf8))
        XCTAssertEqual(state.settings.batchSize, 25)
        XCTAssertEqual(state.settings.rules, ReviewRules())
        XCTAssertTrue(state.cards.isEmpty)
    }

    func testSearchIgnoresCaseAndAccents() {
        var card = Card(id: "abc")
        card.title = "Café Poca"
        card.text = "Open Tue–Sun · 608 E Broadway"
        XCTAssertTrue(TextRules.matches(card.searchText, TextRules.tokens("cafe BROADWAY")))
        XCTAssertFalse(TextRules.matches(card.searchText, TextRules.tokens("cafe pizza")))
    }

    func testSearchFindsTheGroupName() {
        var card = Card(id: "abc")
        card.group = "cook"
        XCTAssertTrue(TextRules.matches(card.searchText, TextRules.tokens("cook")))
    }
}
