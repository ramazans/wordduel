import Foundation
import SwiftData

@Model
public final class Round {
    public var index: Int
    public var askerRoleRaw: String
    public var word: String
    public var expectedAnswer: String
    public var answerGiven: String?
    public var judgementRaw: String
    public var pointsAwarded: Int
    public var isRepeat: Bool
    public var originRoundIndex: Int?
    public var startedAt: Date?
    public var resolvedAt: Date?

    public var match: Match?

    public var askerRole: AskerRole {
        get { AskerRole(rawValue: askerRoleRaw) ?? .host }
        set { askerRoleRaw = newValue.rawValue }
    }

    public var judgement: Judgement {
        get { Judgement(rawValue: judgementRaw) ?? .pendingReview }
        set { judgementRaw = newValue.rawValue }
    }

    public init(
        index: Int,
        askerRole: AskerRole,
        word: String,
        expectedAnswer: String,
        isRepeat: Bool = false,
        originRoundIndex: Int? = nil
    ) {
        self.index = index
        self.askerRoleRaw = askerRole.rawValue
        self.word = word
        self.expectedAnswer = expectedAnswer
        self.judgementRaw = Judgement.pendingReview.rawValue
        self.pointsAwarded = 0
        self.isRepeat = isRepeat
        self.originRoundIndex = originRoundIndex
    }
}
