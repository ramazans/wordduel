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

    func testNormalizeUppercasesAndFilters() {
        XCTAssertEqual(MatchCodeGenerator.normalize("ab23k9"), "AB23K9")
        // 'I' filtered out, 'L' filtered out, 'O' filtered out
        XCTAssertEqual(MatchCodeGenerator.normalize(" ab-23 k9 "), "AB23K9")
    }

    func testNormalizeDropsDisallowedAmbiguous() {
        // 'O', '1', 'I', 'L' kaldırılır; geri kalan 6'a kırpılır
        XCTAssertEqual(MatchCodeGenerator.normalize("OAB1IL23K9"), "AB23K9")
    }

    func testNormalizeTrimsToCodeLength() {
        XCTAssertEqual(MatchCodeGenerator.normalize("AB23K9XYZ").count, 6)
    }

    func testIsValidAcceptsCorrectCode() {
        XCTAssertTrue(MatchCodeGenerator.isValid("AB23K9"))
    }

    func testIsValidRejectsTooShort() {
        XCTAssertFalse(MatchCodeGenerator.isValid("AB23K"))
    }

    func testIsValidRejectsLowercase() {
        XCTAssertFalse(MatchCodeGenerator.isValid("ab23k9"))
    }

    func testIsValidRejectsAmbiguous() {
        XCTAssertFalse(MatchCodeGenerator.isValid("AB23O9"))
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
