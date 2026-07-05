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

    // MARK: - İçerik türleri

    func testEntryWithoutKindDefaultsToWord() throws {
        let json = #"[{"text": "cat", "definition": "kedi", "level": "a1"}]"#
        let words = try SeedLoader.decode(Data(json.utf8))
        XCTAssertEqual(words[0].kind, .word)
    }

    func testExplicitKindsDecode() throws {
        let json = #"""
        [
          {"text": "break the ice", "definition": "buzları eritmek", "level": "b2", "kind": "idiom"},
          {"text": "give up", "definition": "vazgeçmek, bırakmak", "level": "a2", "kind": "phrasal"}
        ]
        """#
        let words = try SeedLoader.decode(Data(json.utf8))
        XCTAssertEqual(words[0].kind, .idiom)
        XCTAssertEqual(words[1].kind, .phrasal)
    }

    func testUnknownKindFallsBackToWordInsteadOfFailing() throws {
        let json = #"[{"text": "x", "definition": "y", "level": "b1", "kind": "grammar"}]"#
        let words = try SeedLoader.decode(Data(json.utf8))
        XCTAssertEqual(words[0].kind, .word)
    }

    func testBundledFileContainsAllKinds() throws {
        let words = try SeedLoader.load()
        let byKind = Dictionary(grouping: words, by: \.kind)
        XCTAssertGreaterThanOrEqual(byKind[.word]?.count ?? 0, 30)
        XCTAssertGreaterThanOrEqual(byKind[.idiom]?.count ?? 0, 45)
        XCTAssertGreaterThanOrEqual(byKind[.phrasal]?.count ?? 0, 45)

        let validLevels = Set(["a1", "a2", "b1", "b2", "c1", "c2"])
        XCTAssertTrue(words.allSatisfy { validLevels.contains($0.level) })
    }

    func testBundledDefinitionsUniqueWithinKind() throws {
        let words = try SeedLoader.load()
        for (kind, group) in Dictionary(grouping: words, by: \.kind) {
            let definitions = group.map { $0.definition.lowercased() }
            XCTAssertEqual(
                definitions.count, Set(definitions).count,
                "Aynı tür (\(kind)) içinde birebir aynı tanım var — MCQ şıkları belirsizleşir"
            )
        }
    }
}
