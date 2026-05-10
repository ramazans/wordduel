import XCTest
@testable import CoreModels

final class CoreModelsTests: XCTestCase {
    func testPendingRepeatItemRoundTrip() throws {
        let item = PendingRepeatItem(
            word: "ephemeral",
            expectedAnswer: "geçici",
            dueAtRoundIndex: 5,
            weight: 2
        )
        let data = try JSONEncoder().encode([item])
        let decoded = try JSONDecoder().decode([PendingRepeatItem].self, from: data)
        XCTAssertEqual(decoded, [item])
    }

    func testMatchStatusEnum() {
        XCTAssertEqual(MatchStatus.allCases.count, 3)
    }
}
