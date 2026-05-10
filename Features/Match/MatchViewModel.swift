import Foundation
import Observation
import CoreModels
import MatchEngine

/// UI state + MatchEngine köprüsü. Faz 4'te CloudKit sync de eklenecek.
@MainActor
@Observable
public final class MatchViewModel {
    public private(set) var snapshot: MatchEngine.Snapshot?
    public var answerDraft: String = ""
    public private(set) var roundStartedAt: Date?

    private let engine: MatchEngine

    public init(config: MatchEngine.Config = .init()) {
        self.engine = MatchEngine(config: config)
    }

    public func refresh() async {
        snapshot = await engine.snapshot()
    }

    // MARK: - Asker actions

    public func askWord(_ word: String, expected: String, asker: MatchEngine.AskerRole) async throws {
        try await engine.askWord(word, expectedAnswer: expected, asker: asker)
        roundStartedAt = .now
        await refresh()
    }

    public func askRepeat(_ item: MatchEngine.PendingItem, asker: MatchEngine.AskerRole) async throws {
        try await engine.askRepeat(item, asker: asker)
        roundStartedAt = .now
        await refresh()
    }

    // MARK: - Answerer actions

    @discardableResult
    public func submitAnswer() async throws -> AnswerNormalizer.AutoVerdict {
        let verdict = try await engine.submitAnswer(answerDraft)
        answerDraft = ""
        await refresh()
        return verdict
    }

    public func submitTimeout() async throws {
        _ = try await engine.submitAnswer(nil)
        answerDraft = ""
        await refresh()
    }

    // MARK: - Asker manual review

    public func confirmManual(isCorrect: Bool) async throws {
        try await engine.confirmManual(isCorrect: isCorrect)
        await refresh()
    }

    // MARK: - Round transition

    public func advance() async throws {
        try await engine.advance()
        roundStartedAt = nil
        await refresh()
    }

    // MARK: - Reads

    public func dueRepeats() async -> [MatchEngine.PendingItem] {
        await engine.dueRepeats()
    }
}
