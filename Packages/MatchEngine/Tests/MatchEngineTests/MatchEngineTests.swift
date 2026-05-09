import XCTest
@testable import MatchEngine

final class MatchEngineTests: XCTestCase {
    func testWrongAnswerAwardsTwoPointsAndQueues() async {
        let engine = MatchEngine()
        let outcome = await engine.resolve(
            word: "ephemeral",
            expectedAnswer: "geçici",
            answerGiven: nil,
            askerIsHost: true
        )
        XCTAssertEqual(outcome.pointsAwarded, 2)
        XCTAssertEqual(outcome.newWeight, 2)

        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 2)
        XCTAssertEqual(snap.guestScore, 0)
        XCTAssertEqual(snap.pending.count, 1)
        // dueAt = currentRoundIndex (=0) + repeatInterval (=3) at the moment of resolve
        XCTAssertEqual(snap.pending.first?.dueAtRoundIndex, 3)
    }

    func testCorrectAnswerNoPointsNoQueue() async {
        let engine = MatchEngine()
        let outcome = await engine.resolve(
            word: "cat",
            expectedAnswer: "cat",
            answerGiven: "cat",
            askerIsHost: true
        )
        XCTAssertEqual(outcome.verdict, .correct)
        XCTAssertEqual(outcome.pointsAwarded, 0)
        XCTAssertNil(outcome.newWeight)

        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 0)
        XCTAssertTrue(snap.pending.isEmpty)
    }

    func testFullCascadeFourteenPoints() async {
        let engine = MatchEngine()
        // İlk yanlış: +2
        var outcome = await engine.resolve(
            word: "abundant",
            expectedAnswer: "bol",
            answerGiven: nil,
            askerIsHost: true
        )
        XCTAssertEqual(outcome.pointsAwarded, 2)

        // 1. tekrar yanlış: +4
        outcome = await engine.resolve(
            word: "abundant",
            expectedAnswer: "bol",
            answerGiven: nil,
            askerIsHost: true,
            existingWeight: 2
        )
        XCTAssertEqual(outcome.pointsAwarded, 4)

        // 2. tekrar yanlış: +8, kuyruktan düşer
        outcome = await engine.resolve(
            word: "abundant",
            expectedAnswer: "bol",
            answerGiven: nil,
            askerIsHost: true,
            existingWeight: 3
        )
        XCTAssertEqual(outcome.pointsAwarded, 8)
        XCTAssertNil(outcome.newWeight)

        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 14, "2 + 4 + 8 = 14")
    }

    func testGuestAskerScoresGuest() async {
        let engine = MatchEngine()
        _ = await engine.resolve(
            word: "scarce",
            expectedAnswer: "kıt",
            answerGiven: nil,
            askerIsHost: false
        )
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.guestScore, 2)
        XCTAssertEqual(snap.hostScore, 0)
    }
}
