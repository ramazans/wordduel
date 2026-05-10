import Foundation

public enum MatchStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case active
    case finished
}

public enum AskerRole: String, Codable, Sendable {
    case host
    case guest
}

public enum Judgement: String, Codable, Sendable {
    case correct
    case wrong
    case pendingReview
}

public enum CEFRLevel: String, Codable, Sendable, CaseIterable {
    case a1, a2, b1, b2, c1, c2
}

public enum ScoreReason: String, Codable, Sendable {
    case autoCorrect
    case autoWrong
    case manualAccept
    case manualReject
    case timeout
}

public struct PendingRepeatItem: Codable, Hashable, Sendable {
    public var word: String
    public var expectedAnswer: String
    public var dueAtRoundIndex: Int
    public var weight: Int

    public init(word: String, expectedAnswer: String, dueAtRoundIndex: Int, weight: Int) {
        self.word = word
        self.expectedAnswer = expectedAnswer
        self.dueAtRoundIndex = dueAtRoundIndex
        self.weight = weight
    }
}
