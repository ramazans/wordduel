import XCTest
@testable import CloudKitService

final class MatchCodeGeneratorTests: XCTestCase {
    func testGeneratedCodeIsCorrectLength() {
        for _ in 0..<50 {
            let code = MatchCodeGenerator.generate()
            XCTAssertEqual(code.count, MatchCodeGenerator.codeLength)
        }
    }

    func testGeneratedCodesUseAlphabetOnly() {
        let allowed = Set(MatchCodeGenerator.alphabet)
        for _ in 0..<50 {
            let code = MatchCodeGenerator.generate()
            XCTAssertTrue(code.allSatisfy { allowed.contains($0) })
        }
    }

    func testAlphabetExcludesAmbiguous() {
        let alphabet = Set(MatchCodeGenerator.alphabet)
        for ambiguous in ["0", "1", "I", "L", "O"] {
            XCTAssertFalse(
                alphabet.contains(Character(ambiguous)),
                "Alphabet should exclude ambiguous \(ambiguous)"
            )
        }
    }

    func testAlphabetContainsNoDigits() {
        let alphabet = Set(MatchCodeGenerator.alphabet)
        for digit in "0123456789" {
            XCTAssertFalse(alphabet.contains(digit), "Alphabet should not contain digit \(digit)")
        }
    }

    func testNormalizeUppercasesAndFilters() {
        XCTAssertEqual(MatchCodeGenerator.normalize("abcdef"), "ABCDEF")
        // Spaces and dashes stripped; result uppercase
        XCTAssertEqual(MatchCodeGenerator.normalize(" ab-cd ef "), "ABCDEF")
    }

    func testNormalizeDropsDisallowedAmbiguous() {
        // 'O', 'I', 'L' ve rakamlar kaldırılır; geri kalan 6'a kırpılır
        XCTAssertEqual(MatchCodeGenerator.normalize("OABCILDEF"), "ABCDEF")
    }

    func testNormalizeDropsDigits() {
        // Rakamlar artık alfabede yok — normalize ederken düşer
        XCTAssertEqual(MatchCodeGenerator.normalize("A1B2C3D4E5F6"), "ABCDEF")
    }

    func testNormalizeTrimsToCodeLength() {
        XCTAssertEqual(MatchCodeGenerator.normalize("ABCDEFXYZ").count, 6)
    }

    func testIsValidAcceptsCorrectCode() {
        XCTAssertTrue(MatchCodeGenerator.isValid("ABCDEF"))
    }

    func testIsValidRejectsTooShort() {
        XCTAssertFalse(MatchCodeGenerator.isValid("ABCDE"))
    }

    func testIsValidRejectsLowercase() {
        XCTAssertFalse(MatchCodeGenerator.isValid("abcdef"))
    }

    func testIsValidRejectsAmbiguous() {
        XCTAssertFalse(MatchCodeGenerator.isValid("ABCDOF"))
    }

    func testIsValidRejectsDigits() {
        XCTAssertFalse(MatchCodeGenerator.isValid("ABC2EF"))
    }

    func testCustomGeneratorIsDeterministic() {
        struct Fixed: RandomNumberGenerator {
            var state: UInt64 = 0
            mutating func next() -> UInt64 { state += 1; return state }
        }
        var rng = Fixed()
        let a = MatchCodeGenerator.generate(using: &rng)
        var rng2 = Fixed()
        let b = MatchCodeGenerator.generate(using: &rng2)
        XCTAssertEqual(a, b)
    }
}
