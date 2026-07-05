import XCTest
@testable import WordRepository

final class OptionsBuilderTests: XCTestCase {
    /// Deterministik testler için basit SplitMix64 RNG.
    private struct SeededRNG: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    private func makePool() -> [SeedWord] {
        var pool: [SeedWord] = []
        for i in 0..<10 {
            pool.append(SeedWord(text: "idiom\(i)", definition: "deyim tanımı \(i)", level: i < 5 ? "b1" : "b2", kind: .idiom))
            pool.append(SeedWord(text: "phrasal\(i)", definition: "phrasal tanımı \(i)", level: "a2", kind: .phrasal))
            pool.append(SeedWord(text: "word\(i)", definition: "kelime tanımı \(i)", level: "b1", kind: .word))
        }
        return pool
    }

    func testProducesFourOptionsWithCorrectExactlyOnce() {
        var rng = SeededRNG(state: 42)
        let options = OptionsBuilder.multipleChoiceOptions(
            correct: "buzları eritmek",
            kind: .idiom,
            level: "b1",
            pool: makePool(),
            using: &rng
        )
        XCTAssertEqual(options.count, 4)
        XCTAssertEqual(options.filter { $0 == "buzları eritmek" }.count, 1)
        XCTAssertEqual(Set(options).count, 4)
    }

    func testDeterministicWithSeededRNG() {
        var rng1 = SeededRNG(state: 7)
        var rng2 = SeededRNG(state: 7)
        let pool = makePool()
        let a = OptionsBuilder.multipleChoiceOptions(correct: "x", kind: .idiom, level: "b1", pool: pool, using: &rng1)
        let b = OptionsBuilder.multipleChoiceOptions(correct: "x", kind: .idiom, level: "b1", pool: pool, using: &rng2)
        XCTAssertEqual(a, b)
    }

    func testDistractorsComeFromSameKindWhenPoolSuffices() {
        var rng = SeededRNG(state: 3)
        let pool = makePool()
        let options = OptionsBuilder.multipleChoiceOptions(
            correct: "buzları eritmek",
            kind: .idiom,
            level: "b1",
            pool: pool,
            using: &rng
        )
        let idiomDefinitions = Set(pool.filter { $0.kind == .idiom }.map(\.definition))
        for option in options where option != "buzları eritmek" {
            XCTAssertTrue(idiomDefinitions.contains(option), "Şık aynı türden gelmeli: \(option)")
        }
    }

    func testSameLevelPreferredWhenAvailable() {
        var rng = SeededRNG(state: 11)
        let pool = makePool() // 5 idiom b1 + 5 idiom b2
        let options = OptionsBuilder.multipleChoiceOptions(
            correct: "hedef",
            kind: .idiom,
            level: "b1",
            pool: pool,
            using: &rng
        )
        let b1Definitions = Set(pool.filter { $0.kind == .idiom && $0.level == "b1" }.map(\.definition))
        for option in options where option != "hedef" {
            XCTAssertTrue(b1Definitions.contains(option), "Aynı seviye tercih edilmeli: \(option)")
        }
    }

    func testCorrectDefinitionNeverDuplicatedFromPool() {
        // Doğru cevap havuzda da varsa (kendi girişi) şıklarda bir kez görünmeli.
        var rng = SeededRNG(state: 5)
        let pool = makePool()
        let correct = "deyim tanımı 2" // havuzdaki bir idiom tanımı
        let options = OptionsBuilder.multipleChoiceOptions(
            correct: correct, kind: .idiom, level: "b1", pool: pool, using: &rng
        )
        XCTAssertEqual(options.filter { $0.lowercased() == correct }.count, 1)
        XCTAssertEqual(options.count, 4)
    }

    func testSmallPoolDegradesGracefully() {
        var rng = SeededRNG(state: 1)
        let tiny = [
            SeedWord(text: "a", definition: "tanım bir", level: "b1", kind: .idiom),
            SeedWord(text: "b", definition: "tanım iki", level: "b1", kind: .idiom)
        ]
        let options = OptionsBuilder.multipleChoiceOptions(
            correct: "doğru cevap", kind: .idiom, level: "b1", pool: tiny, using: &rng
        )
        // 2 aday + doğru = 3 şık; asla patlamaz, çağıran count < 4 görüp metne düşer.
        XCTAssertEqual(options.count, 3)
        XCTAssertTrue(options.contains("doğru cevap"))
    }

    func testEmptyPoolReturnsOnlyCorrect() {
        var rng = SeededRNG(state: 1)
        let options = OptionsBuilder.multipleChoiceOptions(
            correct: "tek", kind: .word, level: nil, pool: [], using: &rng
        )
        XCTAssertEqual(options, ["tek"])
    }
}
