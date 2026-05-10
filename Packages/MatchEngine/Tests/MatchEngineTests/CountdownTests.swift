import XCTest
@testable import MatchEngine

final class CountdownTests: XCTestCase {
    func testRemainingFullDurationAtStart() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        XCTAssertEqual(cd.remainingSeconds(now: start), 30)
    }

    func testRemainingHalfWayThrough() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        let now = Date(timeIntervalSince1970: 1015)
        XCTAssertEqual(cd.remainingSeconds(now: now), 15)
    }

    func testRemainingNeverNegative() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        let now = Date(timeIntervalSince1970: 9999)
        XCTAssertEqual(cd.remainingSeconds(now: now), 0)
    }

    func testRemainingWhenNowBeforeStart() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        let now = Date(timeIntervalSince1970: 500)
        XCTAssertEqual(cd.remainingSeconds(now: now), 30, "Future start clamps elapsed to 0")
    }

    func testIsExpiredFlag() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        XCTAssertFalse(cd.isExpired(now: Date(timeIntervalSince1970: 1029)))
        XCTAssertTrue(cd.isExpired(now: Date(timeIntervalSince1970: 1031)))
    }

    func testSeverityNormal() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        XCTAssertEqual(cd.severity(now: Date(timeIntervalSince1970: 1010)), .normal)
    }

    func testSeverityWarningAtTenSecondsLeft() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        XCTAssertEqual(cd.severity(now: Date(timeIntervalSince1970: 1020)), .warning)
    }

    func testSeverityExpired() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: 30)
        XCTAssertEqual(cd.severity(now: Date(timeIntervalSince1970: 1030)), .expired)
    }

    func testNegativeDurationClampsToZero() {
        let start = Date(timeIntervalSince1970: 1000)
        let cd = Countdown(startedAt: start, durationSeconds: -5)
        XCTAssertEqual(cd.durationSeconds, 0)
        XCTAssertTrue(cd.isExpired(now: start))
    }
}
