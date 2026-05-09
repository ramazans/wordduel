import XCTest
@testable import MatchEngine

final class AnswerNormalizerTests: XCTestCase {
    func testNormalizeStripsDiacriticsAndCase() {
        XCTAssertEqual(AnswerNormalizer.normalize("  Çekíç  "), "cekic")
    }

    func testToleranceShortWordIsZero() {
        XCTAssertEqual(AnswerNormalizer.tolerance(for: 4), 0)
    }

    func testToleranceMediumWordIsOne() {
        XCTAssertEqual(AnswerNormalizer.tolerance(for: 6), 1)
    }

    func testToleranceLongWordIsTwo() {
        XCTAssertEqual(AnswerNormalizer.tolerance(for: 10), 2)
    }

    func testExactMatchIsCorrect() {
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "ephemeral", expected: "ephemeral"),
            .correct
        )
    }

    func testTypoWithinToleranceIsCorrect() {
        // "ephemerals" vs "ephemeral" — distance 1, length 9 → tolerance 2 → correct
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "ephemerals", expected: "ephemeral"),
            .correct
        )
    }

    func testStudiedVsStudyIsNotCorrect() {
        // Plan: "studied" ↔ "study" — distance 4, NOT auto-correct
        XCTAssertNotEqual(
            AnswerNormalizer.autoJudge(answer: "studied", expected: "study"),
            .correct
        )
    }

    func testShortWordTypoNeedsManualReview() {
        // "cat" vs "bat" — distance 1, length 3 → tolerance 0 → needs manual
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "cat", expected: "bat"),
            .needsManualReview
        )
    }

    func testEmptyAnswerIsWrong() {
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "  ", expected: "anything"),
            .wrong
        )
    }
}
