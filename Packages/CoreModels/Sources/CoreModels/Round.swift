import Foundation
import SwiftData

@Model
public final class Round {
    public var index: Int = 0
    public var askerRoleRaw: String = "host"
    public var word: String = ""
    public var expectedAnswer: String = ""
    public var answerGiven: String?
    public var judgementRaw: String = "pendingReview"
    public var pointsAwarded: Int = 0
    public var isRepeat: Bool = false
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
