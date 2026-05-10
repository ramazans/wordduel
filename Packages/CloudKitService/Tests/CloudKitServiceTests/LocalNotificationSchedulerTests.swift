import XCTest
import UserNotifications
@testable import CloudKitService

final class LocalNotificationSchedulerTests: XCTestCase {
    func testTurnNotificationIdentifierIncludesCode() {
        let turn = LocalNotificationScheduler.TurnNotification(
            matchCode: "AB23K9",
            title: "Sıra sende",
            body: "Maç AB23K9'da sıra sana geldi."
        )
        XCTAssertEqual(turn.identifier, "wordduel.turn.AB23K9")
    }

    func testIdentifierPrefixIsStable() {
        XCTAssertEqual(
            LocalNotificationScheduler.TurnNotification.identifierPrefix,
            "wordduel.turn."
        )
    }

    func testAuthorizationStatusMapping() {
        XCTAssertEqual(LocalNotificationScheduler.map(.authorized), .authorized)
        XCTAssertEqual(LocalNotificationScheduler.map(.denied), .denied)
        XCTAssertEqual(LocalNotificationScheduler.map(.provisional), .provisional)
        XCTAssertEqual(LocalNotificationScheduler.map(.notDetermined), .notDetermined)
        XCTAssertEqual(LocalNotificationScheduler.map(.ephemeral), .ephemeral)
    }
}
