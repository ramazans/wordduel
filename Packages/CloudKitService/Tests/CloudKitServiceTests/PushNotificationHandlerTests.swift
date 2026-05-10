import XCTest
@testable import CloudKitService

final class PushNotificationHandlerTests: XCTestCase {
    func testEmptyPayloadIsIgnored() {
        let outcome = PushNotificationHandler.handle(userInfo: [:])
        XCTAssertEqual(outcome, .ignored)
    }

    func testNonCloudKitPayloadIsIgnored() {
        let outcome = PushNotificationHandler.handle(userInfo: [
            "aps": ["alert": "hi"]
        ])
        XCTAssertEqual(outcome, .ignored)
    }
}

final class SubscriptionScopeTests: XCTestCase {
    func testScopeIDsAreStable() {
        XCTAssertEqual(SubscriptionManager.Scope.privateDB.rawValue, "wordduel.privateDB.subscription")
        XCTAssertEqual(SubscriptionManager.Scope.sharedDB.rawValue, "wordduel.sharedDB.subscription")
    }

    func testAllCasesHasTwo() {
        XCTAssertEqual(SubscriptionManager.Scope.allCases.count, 2)
    }
}
