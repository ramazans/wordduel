import XCTest
@testable import MatchEngine

final class ScoringTests: XCTestCase {
    func testFirstWrongIs2Points() {
        XCTAssertEqual(Scoring.points(forWeight: 1), 2)
    }

    func testFirstRepeatWrongIs4Points() {
        XCTAssertEqual(Scoring.points(forWeight: 2), 4)
    }

    func testSecondRepeatWrongIs8Points() {
        XCTAssertEqual(Scoring.points(forWeight: 3), 8)
    }

    func testZeroWeightYieldsZero() {
        XCTAssertEqual(Scoring.points(forWeight: 0), 0)
    }

    func testFullCascade() {
        let total = Scoring.points(forWeight: 1)
                  + Scoring.points(forWeight: 2)
                  + Scoring.points(forWeight: 3)
        XCTAssertEqual(total, 14, "2 + 4 + 8 = 14")
    }
}
