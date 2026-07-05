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
        // "studied" vs "study" — distance 3, length 5 → tolerance 1 → not auto-correct
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

    // MARK: - Eş anlamlı varyantlar

    func testExpectedVariantsSplitsOnCommaAndSemicolon() {
        XCTAssertEqual(
            AnswerNormalizer.expectedVariants("vazgeçmek, bırakmak; terk etmek"),
            ["vazgeçmek, bırakmak; terk etmek", "vazgeçmek", "bırakmak", "terk etmek"]
        )
        XCTAssertEqual(AnswerNormalizer.expectedVariants("bol"), ["bol"])
    }

    func testSingleSynonymOfCommaListIsCorrect() {
        // Tek eş anlamlı yazmak yeterli — eskiden tam string'e Levenshtein
        // uygulanıp manuel incelemeye düşüyordu.
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "vazgeçmek", expected: "vazgeçmek, bırakmak"),
            .correct
        )
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "bol", expected: "bol, çok miktarda"),
            .correct
        )
    }

    func testSynonymTypoWithinToleranceIsCorrect() {
        // "bırakmk" vs "bırakmak" — uzunluk 8 → tolerans 2, mesafe 1 → correct
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "bırakmk", expected: "vazgeçmek, bırakmak"),
            .correct
        )
    }

    func testSemicolonSeparatedVariantMatches() {
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "yaklaşmak", expected: "yaklaşım; yaklaşmak"),
            .correct
        )
    }

    func testFullStringAnswerStillCorrect() {
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "vazgeçmek, bırakmak", expected: "vazgeçmek, bırakmak"),
            .correct
        )
    }

    func testUnrelatedAnswerAgainstSynonymListNeedsManualReview() {
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "koşmak", expected: "vazgeçmek, bırakmak"),
            .needsManualReview
        )
    }

    func testShortSynonymNoToleranceMismatchNeedsManualReview() {
        // "bal" vs "bol" — kısa varyant tolerans 0 → manuel inceleme
        XCTAssertEqual(
            AnswerNormalizer.autoJudge(answer: "bal", expected: "bol, çok miktarda"),
            .needsManualReview
        )
    }
}
