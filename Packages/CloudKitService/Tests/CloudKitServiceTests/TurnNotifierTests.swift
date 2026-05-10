import XCTest
@testable import CloudKitService

final class TurnNotifierTests: XCTestCase {
    func testEmptyMatchesProducesNoNotifications() {
        let notifier = TurnNotifier()
        XCTAssertTrue(notifier.notifications(for: []).isEmpty)
    }

    func testOnlyMatchesWhereItsMyTurnAreReturned() {
        let notifier = TurnNotifier()
        let matches: [TurnNotifier.ActiveMatch] = [
            .init(code: "AAA111", isMyTurnToAnswer: true, opponentDisplayName: "Ali"),
            .init(code: "BBB222", isMyTurnToAnswer: false, opponentDisplayName: "Ayşe"),
            .init(code: "CCC333", isMyTurnToAnswer: true, opponentDisplayName: "Mehmet")
        ]
        let notifications = notifier.notifications(for: matches)
        XCTAssertEqual(notifications.map(\.matchCode), ["AAA111", "CCC333"])
    }

    func testDefaultTitleAndBodyContainContext() {
        let notifier = TurnNotifier()
        let match = TurnNotifier.ActiveMatch(
            code: "AB23K9",
            isMyTurnToAnswer: true,
            opponentDisplayName: "Ali"
        )
        let notifications = notifier.notifications(for: [match])
        XCTAssertEqual(notifications.first?.title, "Sıra sende")
        XCTAssertTrue(notifications.first?.body.contains("Ali") ?? false)
        XCTAssertTrue(notifications.first?.body.contains("AB23K9") ?? false)
    }

    func testCustomTitleAndBodyAreUsed() {
        let notifier = TurnNotifier()
        let match = TurnNotifier.ActiveMatch(
            code: "AB23K9",
            isMyTurnToAnswer: true,
            opponentDisplayName: "Ali"
        )
        let notifications = notifier.notifications(
            for: [match],
            titleFor: { _ in "Your turn" },
            bodyFor: { _ in "Opponent waiting" }
        )
        XCTAssertEqual(notifications.first?.title, "Your turn")
        XCTAssertEqual(notifications.first?.body, "Opponent waiting")
    }
}
