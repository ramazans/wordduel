import XCTest
@testable import WordRepository

final class SeedLoaderTests: XCTestCase {
    func testDecodesValidJSON() throws {
        let json = #"""
        [
          {"text": "cat", "definition": "kedi", "level": "a1"},
          {"text": "dog", "definition": "köpek", "level": "a1"}
        ]
        """#
        let words = try SeedLoader.decode(Data(json.utf8))
        XCTAssertEqual(words.count, 2)
        XCTAssertEqual(words[0].text, "cat")
        XCTAssertEqual(words[1].definition, "köpek")
    }

    func testFailsOnInvalidJSON() {
        XCTAssertThrowsError(try SeedLoader.decode(Data("nope".utf8)))
    }

    func testLoadsBundledSeedFile() throws {
        let words = try SeedLoader.load()
        XCTAssertGreaterThan(words.count, 20)
        XCTAssertTrue(words.contains { $0.text == "ephemeral" })
    }
}
