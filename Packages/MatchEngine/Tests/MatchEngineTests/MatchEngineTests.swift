import XCTest
@testable import MatchEngine

final class MatchEngineTests: XCTestCase {

    // MARK: - Initial state

    func test01_initialPhaseIsIdle() async {
        let engine = MatchEngine()
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.phase, .idle)
        XCTAssertEqual(snap.currentRoundIndex, 0)
        XCTAssertEqual(snap.hostScore, 0)
        XCTAssertEqual(snap.guestScore, 0)
        XCTAssertNil(snap.activeRound)
        XCTAssertNil(snap.winner)
    }

    func test02_defaultConfigUsesPlanValues() async {
        let snap = await MatchEngine().snapshot()
        XCTAssertEqual(snap.totalRounds, 10)
    }

    // MARK: - Auto correct path

    func test03_autoCorrectAwardsNoPoints() async throws {
        let engine = MatchEngine()
        try await engine.askWord("cat", expectedAnswer: "kedi", asker: .host)
        let verdict = try await engine.submitAnswer("kedi")
        XCTAssertEqual(verdict, .correct)

        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 0)
        XCTAssertEqual(snap.phase, .reviewed)
        XCTAssertTrue(snap.pending.isEmpty)
    }

    func test04_autoCorrectWithDiacritics() async throws {
        let engine = MatchEngine()
        try await engine.askWord("apple", expectedAnswer: "elma", asker: .host)
        let verdict = try await engine.submitAnswer("ELMA  ")
        XCTAssertEqual(verdict, .correct)
    }

    // MARK: - Auto wrong path

    func test05_autoWrongAwardsTwoPointsToHost() async throws {
        let engine = MatchEngine()
        try await engine.askWord("ephemeral", expectedAnswer: "geçici", asker: .host)
        let verdict = try await engine.submitAnswer(nil)
        XCTAssertEqual(verdict, .wrong)

        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 2)
        XCTAssertEqual(snap.guestScore, 0)
        XCTAssertEqual(snap.pending.count, 1)
        XCTAssertEqual(snap.pending.first?.weight, 2)
    }

    func test06_emptyAnswerCountsAsWrong() async throws {
        let engine = MatchEngine()
        try await engine.askWord("ephemeral", expectedAnswer: "geçici", asker: .host)
        let verdict = try await engine.submitAnswer("   ")
        XCTAssertEqual(verdict, .wrong)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 2)
    }

    func test07_guestAskerScoresGuest() async throws {
        let engine = MatchEngine()
        try await engine.askWord("scarce", expectedAnswer: "kıt", asker: .guest)
        _ = try await engine.submitAnswer(nil)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.guestScore, 2)
        XCTAssertEqual(snap.hostScore, 0)
    }

    // MARK: - Manual review path

    func test08_ambiguousAnswerEntersManualReview() async throws {
        let engine = MatchEngine()
        try await engine.askWord("cat", expectedAnswer: "kedi", asker: .host)
        // "kedy" — distance 1, length 4 → tolerance 0 → manual review
        let verdict = try await engine.submitAnswer("kedy")
        XCTAssertEqual(verdict, .needsManualReview)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.phase, .manualReview)
        XCTAssertEqual(snap.hostScore, 0, "Score not applied until confirmManual")
    }

    func test09_manualConfirmCorrectAwardsNothing() async throws {
        let engine = MatchEngine()
        try await engine.askWord("cat", expectedAnswer: "kedi", asker: .host)
        _ = try await engine.submitAnswer("kedy")
        try await engine.confirmManual(isCorrect: true)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 0)
        XCTAssertEqual(snap.phase, .reviewed)
        XCTAssertTrue(snap.pending.isEmpty)
    }

    func test10_manualConfirmWrongAwardsPoints() async throws {
        let engine = MatchEngine()
        try await engine.askWord("cat", expectedAnswer: "kedi", asker: .host)
        _ = try await engine.submitAnswer("kedy")
        try await engine.confirmManual(isCorrect: false)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 2)
        XCTAssertEqual(snap.pending.count, 1)
    }

    // MARK: - Repeat queue mechanics

    func test11_pendingHasCorrectDueIndex() async throws {
        let engine = MatchEngine()  // repeatInterval = 3
        try await engine.askWord("ephemeral", expectedAnswer: "geçici", asker: .host)
        _ = try await engine.submitAnswer(nil)
        let snap = await engine.snapshot()
        // currentRoundIndex still 0 (advance not called)
        XCTAssertEqual(snap.pending.first?.dueAtRoundIndex, 3)
    }

    func test12_dueRepeatsExcludesFutureItems() async throws {
        let engine = MatchEngine()
        try await engine.askWord("w1", expectedAnswer: "a1", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        let due = await engine.dueRepeats()
        XCTAssertTrue(due.isEmpty, "Index 1 < dueAt 3")
    }

    func test13_dueRepeatsIncludesItemAtDueIndex() async throws {
        let engine = MatchEngine()
        try await engine.askWord("w1", expectedAnswer: "a1", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        try await engine.askWord("w2", expectedAnswer: "a2", asker: .guest)
        _ = try await engine.submitAnswer("a2")
        try await engine.advance()
        try await engine.askWord("w3", expectedAnswer: "a3", asker: .host)
        _ = try await engine.submitAnswer("a3")
        try await engine.advance()
        // currentRoundIndex == 3 now → dueAt == 3 should be visible
        let due = await engine.dueRepeats()
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.word, "w1")
    }

    func test14_dueRepeatsSortedByDue() async throws {
        let engine = MatchEngine(config: .init(totalRounds: 20, repeatInterval: 1))
        try await engine.askWord("a", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        try await engine.askWord("b", expectedAnswer: "y", asker: .guest)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        try await engine.askWord("c", expectedAnswer: "z", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        let due = await engine.dueRepeats()
        XCTAssertEqual(due.map(\.word), ["a", "b", "c"])
    }

    func test15_consumeRepeatRemovesItem() async throws {
        let engine = MatchEngine()
        try await engine.askWord("w", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        let snap1 = await engine.snapshot()
        let item = snap1.pending.first!
        try await engine.advance()
        try await engine.consumeRepeat(item)
        let snap2 = await engine.snapshot()
        XCTAssertTrue(snap2.pending.isEmpty)
    }

    func test16_consumeUnknownRepeatThrows() async throws {
        let engine = MatchEngine()
        let item = MatchEngine.PendingItem(word: "x", expectedAnswer: "y", dueAtRoundIndex: 0, weight: 1)
        do {
            try await engine.consumeRepeat(item)
            XCTFail("Expected throw")
        } catch let MatchEngine.EngineError.repeatNotInQueue {
            // expected
        }
    }

    // MARK: - 2/4/8 cascade

    func test17_firstRepeatWrongAwardsFour() async throws {
        let engine = MatchEngine()
        try await engine.askWord("w", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        var snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .host)
        _ = try await engine.submitAnswer(nil)
        snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 6, "2 + 4")
    }

    func test18_secondRepeatWrongAwardsEightAndDropsFromQueue() async throws {
        let engine = MatchEngine()
        // play through to weight 3
        try await engine.askWord("w", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        var snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .host)
        _ = try await engine.submitAnswer(nil)
        snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 14, "2 + 4 + 8")
        XCTAssertTrue(snap.pending.isEmpty, "weight 3 wrong → drops out")
    }

    func test19_fullCascadeYieldsFourteen() async throws {
        // Same as test18 — kept for the explicit 14 assertion at scoring level
        let engine = MatchEngine()
        try await engine.askWord("w", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        var snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .host)
        _ = try await engine.submitAnswer(nil)
        snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 14, "2 + 4 + 8")
    }

    func test20_repeatAnsweredCorrectlyDropsFromQueueNoPoints() async throws {
        let engine = MatchEngine()
        try await engine.askWord("w", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        let snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .host)
        _ = try await engine.submitAnswer("x")
        let final = await engine.snapshot()
        XCTAssertEqual(final.hostScore, 2, "Only the original wrong scored")
        XCTAssertTrue(final.pending.isEmpty, "Repeat consumed and not pushed back on correct")
    }

    // MARK: - State machine guards

    func test21_askingTwiceThrows() async throws {
        let engine = MatchEngine()
        try await engine.askWord("a", expectedAnswer: "x", asker: .host)
        do {
            try await engine.askWord("b", expectedAnswer: "y", asker: .host)
            XCTFail("Expected wrongPhase")
        } catch let MatchEngine.EngineError.wrongPhase(expected, _) {
            XCTAssertEqual(expected, .idle)
        }
    }

    func test22_submitAnswerInIdleThrows() async throws {
        let engine = MatchEngine()
        do {
            _ = try await engine.submitAnswer("x")
            XCTFail("Expected wrongPhase")
        } catch let MatchEngine.EngineError.wrongPhase(expected, _) {
            XCTAssertEqual(expected, .answering)
        }
    }

    func test23_confirmManualOutsideManualPhaseThrows() async throws {
        let engine = MatchEngine()
        try await engine.askWord("a", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer("x")  // → reviewed (correct)
        do {
            try await engine.confirmManual(isCorrect: true)
            XCTFail("Expected wrongPhase")
        } catch let MatchEngine.EngineError.wrongPhase(expected, _) {
            XCTAssertEqual(expected, .manualReview)
        }
    }

    func test24_advanceFromAnsweringThrows() async throws {
        let engine = MatchEngine()
        try await engine.askWord("a", expectedAnswer: "x", asker: .host)
        do {
            try await engine.advance()
            XCTFail("Expected wrongPhase")
        } catch let MatchEngine.EngineError.wrongPhase(expected, _) {
            XCTAssertEqual(expected, .reviewed)
        }
    }

    // MARK: - Match end & winner

    func test25_matchFinishesAfterTotalRounds() async throws {
        let engine = MatchEngine(config: .init(totalRounds: 2))
        for _ in 0..<2 {
            try await engine.askWord("w", expectedAnswer: "x", asker: .host)
            _ = try await engine.submitAnswer("x")
            try await engine.advance()
        }
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.phase, .finished)
        XCTAssertEqual(snap.winner, .tie)
    }

    func test26_winnerIsHostWhenAhead() async throws {
        let engine = MatchEngine(config: .init(totalRounds: 1))
        try await engine.askWord("w", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.winner, .host)
    }

    func test27_winnerIsGuestWhenAhead() async throws {
        let engine = MatchEngine(config: .init(totalRounds: 1))
        try await engine.askWord("w", expectedAnswer: "x", asker: .guest)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.winner, .guest)
    }

    func test28_askingAfterFinishedThrows() async throws {
        let engine = MatchEngine(config: .init(totalRounds: 1))
        try await engine.askWord("w", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer("x")
        try await engine.advance()
        do {
            try await engine.askWord("w2", expectedAnswer: "x2", asker: .host)
            XCTFail("Expected matchFinished")
        } catch MatchEngine.EngineError.matchFinished {
            // expected
        }
    }

    // MARK: - Active round snapshot

    func test29_activeRoundReflectsAskedWord() async throws {
        let engine = MatchEngine()
        try await engine.askWord("ephemeral", expectedAnswer: "geçici", asker: .guest)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.activeRound?.word, "ephemeral")
        XCTAssertEqual(snap.activeRound?.asker, .guest)
        XCTAssertEqual(snap.activeRound?.weight, 1)
        XCTAssertFalse(snap.activeRound?.isRepeat ?? true)
    }

    func test30_activeRoundClearedAfterAdvance() async throws {
        let engine = MatchEngine()
        try await engine.askWord("a", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer("x")
        try await engine.advance()
        let snap = await engine.snapshot()
        XCTAssertNil(snap.activeRound)
        XCTAssertEqual(snap.phase, .idle)
        XCTAssertEqual(snap.currentRoundIndex, 1)
    }

    // MARK: - LastResolution

    func test31_lastResolutionRecordsCorrect() async throws {
        let engine = MatchEngine()
        try await engine.askWord("a", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer("x")
        let last = await engine.lastResolved()
        XCTAssertEqual(last?.isCorrect, true)
        XCTAssertEqual(last?.pointsAwarded, 0)
        XCTAssertEqual(last?.asker, .host)
        XCTAssertEqual(last?.word, "a")
        XCTAssertNil(last?.nextWeight)
    }

    func test32_lastResolutionRecordsWrong() async throws {
        let engine = MatchEngine()
        try await engine.askWord("a", expectedAnswer: "x", asker: .guest)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        let snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .guest)
        _ = try await engine.submitAnswer(nil)
        let last = await engine.lastResolved()
        XCTAssertEqual(last?.isCorrect, false)
        XCTAssertEqual(last?.pointsAwarded, 4)
        XCTAssertEqual(last?.asker, .guest)
        XCTAssertEqual(last?.nextWeight, 3)
    }

    // MARK: - Mixed scenario

    func test33_mixedSequenceComputesScoresCorrectly() async throws {
        let engine = MatchEngine(config: .init(totalRounds: 4, repeatInterval: 1))
        // Round 0: host asks, guest answers wrong → host +2
        try await engine.askWord("a", expectedAnswer: "x", asker: .host)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        // Round 1: guest asks, host answers right → 0
        try await engine.askWord("b", expectedAnswer: "y", asker: .guest)
        _ = try await engine.submitAnswer("y")
        try await engine.advance()
        // Round 2: host asks repeat (weight 2), guest answers right → 0, drops
        let snap = await engine.snapshot()
        try await engine.askRepeat(snap.pending.first!, asker: .host)
        _ = try await engine.submitAnswer("x")
        try await engine.advance()
        // Round 3: guest asks, host wrong → guest +2
        try await engine.askWord("c", expectedAnswer: "z", asker: .guest)
        _ = try await engine.submitAnswer(nil)
        try await engine.advance()
        let final = await engine.snapshot()
        XCTAssertEqual(final.hostScore, 2)
        XCTAssertEqual(final.guestScore, 2)
        XCTAssertEqual(final.phase, .finished)
        XCTAssertEqual(final.winner, .tie)
    }

    // MARK: - AskerRole helper

    func test34_askerRoleOpponentIsCorrect() {
        XCTAssertEqual(MatchEngine.AskerRole.host.opponent, .guest)
        XCTAssertEqual(MatchEngine.AskerRole.guest.opponent, .host)
    }

    // MARK: - Long Levenshtein → still wrong

    func test35_studyVsStudiedNotAutoCorrect() async throws {
        let engine = MatchEngine()
        try await engine.askWord("study", expectedAnswer: "study", asker: .host)
        let verdict = try await engine.submitAnswer("studied")
        // distance 4, length 5 → tolerance 1 → not correct, but >0 → manual review
        XCTAssertEqual(verdict, .needsManualReview)
    }

    // MARK: - Çoktan seçmeli format

    func test36_multipleChoiceCorrectOptionAwardsNoPoints() async throws {
        let engine = MatchEngine()
        let options = ["vazgeçmek, bırakmak", "ertelemek", "aramak", "devam etmek"]
        try await engine.askWord(
            "give up", expectedAnswer: "vazgeçmek, bırakmak", asker: .host,
            format: .multipleChoice, options: options
        )
        let verdict = try await engine.submitAnswer("vazgeçmek, bırakmak")
        XCTAssertEqual(verdict, .correct)

        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 0)
        XCTAssertEqual(snap.phase, .reviewed)
        XCTAssertTrue(snap.pending.isEmpty)
    }

    func test37_multipleChoiceWrongOptionScoresAndRequeues() async throws {
        let engine = MatchEngine()
        try await engine.askWord(
            "give up", expectedAnswer: "vazgeçmek, bırakmak", asker: .guest,
            format: .multipleChoice, options: ["vazgeçmek, bırakmak", "ertelemek", "aramak", "devam etmek"]
        )
        let verdict = try await engine.submitAnswer("ertelemek")
        // Serbest metinde "ertelemek" manuel incelemeye düşerdi; MCQ'da kesin yanlış.
        XCTAssertEqual(verdict, .wrong)

        let snap = await engine.snapshot()
        XCTAssertEqual(snap.guestScore, 2)
        XCTAssertEqual(snap.pending.count, 1)
        XCTAssertEqual(snap.pending.first?.weight, 2)
        XCTAssertEqual(snap.phase, .reviewed)
    }

    func test38_multipleChoiceNeverEntersManualReview() async throws {
        let engine = MatchEngine()
        try await engine.askWord(
            "cat", expectedAnswer: "kedi", asker: .host,
            format: .multipleChoice, options: ["kedi", "köpek", "kuş", "kefal"]
        )
        // "kefal" vs "kedi": serbest metinde kısa kelime → manuel inceleme olurdu.
        let verdict = try await engine.submitAnswer("kefal")
        XCTAssertEqual(verdict, .wrong)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.phase, .reviewed)
    }

    func test39_multipleChoiceTimeoutIsWrong() async throws {
        let engine = MatchEngine()
        try await engine.askWord(
            "dog", expectedAnswer: "köpek", asker: .host,
            format: .multipleChoice, options: ["kedi", "köpek", "kuş", "at"]
        )
        let verdict = try await engine.submitAnswer(nil)
        XCTAssertEqual(verdict, .wrong)
        let snap = await engine.snapshot()
        XCTAssertEqual(snap.hostScore, 2)
    }

    func test40_repeatOfMissedMCQCanBeAskedAsText() async throws {
        let engine = MatchEngine()
        try await engine.askWord(
            "give up", expectedAnswer: "vazgeçmek", asker: .host,
            format: .multipleChoice, options: ["vazgeçmek", "ertelemek", "aramak", "koşmak"]
        )
        _ = try await engine.submitAnswer("ertelemek") // yanlış → kuyruğa weight 2
        try await engine.advance()

        for _ in 0..<3 { // tekrar vadesi gelsin diye 3 tur oyna
            try await engine.askWord("filler", expectedAnswer: "dolgu sözcük", asker: .guest)
            _ = try await engine.submitAnswer("dolgu sözcük")
            try await engine.advance()
        }

        let due = await engine.dueRepeats()
        XCTAssertEqual(due.count, 1)
        // Tekrar bu kez serbest metin olarak sorulur — format kuyrukta saklanmaz.
        try await engine.askRepeat(due[0], asker: .host)
        let round = await engine.snapshot().activeRound
        XCTAssertEqual(round?.format, .text)
        XCTAssertEqual(round?.weight, 2)

        let verdict = try await engine.submitAnswer("vazgeçmek")
        XCTAssertEqual(verdict, .correct)
    }

    func test41_activeRoundCarriesFormatAndOptions() async throws {
        let engine = MatchEngine()
        let options = ["kedi", "köpek", "kuş", "at"]
        try await engine.askWord(
            "cat", expectedAnswer: "kedi", asker: .host,
            format: .multipleChoice, options: options
        )
        let round = await engine.snapshot().activeRound
        XCTAssertEqual(round?.format, .multipleChoice)
        XCTAssertEqual(round?.options, options)
    }
}
