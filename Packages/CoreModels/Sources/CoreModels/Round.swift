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
    public var kindRaw: String = "word"
    public var formatRaw: String = "text"
    /// Çoktan seçmeli turlarda 4 şık, JSON `[String]` olarak saklanır
    /// (SwiftData'nın CloudKit uyumu için `Match.pendingRepeatsData` kalıbı).
    public var optionsData: Data = Data()

    public var match: Match?

    public var askerRole: AskerRole {
        get { AskerRole(rawValue: askerRoleRaw) ?? .host }
        set { askerRoleRaw = newValue.rawValue }
    }

    public var judgement: Judgement {
        get { Judgement(rawValue: judgementRaw) ?? .pendingReview }
        set { judgementRaw = newValue.rawValue }
    }

    public var kind: ContentKind {
        get { ContentKind(rawValue: kindRaw) ?? .word }
        set { kindRaw = newValue.rawValue }
    }

    public var format: AnswerFormat {
        get { AnswerFormat(rawValue: formatRaw) ?? .text }
        set { formatRaw = newValue.rawValue }
    }

    public var options: [String] {
        get {
            guard !optionsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([String].self, from: optionsData)) ?? []
        }
        set {
            optionsData = newValue.isEmpty ? Data() : ((try? JSONEncoder().encode(newValue)) ?? Data())
        }
    }

    public init(
        index: Int,
        askerRole: AskerRole,
        word: String,
        expectedAnswer: String,
        isRepeat: Bool = false,
        originRoundIndex: Int? = nil,
        kind: ContentKind = .word,
        format: AnswerFormat = .text,
        options: [String] = []
    ) {
        self.index = index
        self.askerRoleRaw = askerRole.rawValue
        self.word = word
        self.expectedAnswer = expectedAnswer
        self.judgementRaw = Judgement.pendingReview.rawValue
        self.pointsAwarded = 0
        self.isRepeat = isRepeat
        self.originRoundIndex = originRoundIndex
        self.kindRaw = kind.rawValue
        self.formatRaw = format.rawValue
        self.optionsData = options.isEmpty ? Data() : ((try? JSONEncoder().encode(options)) ?? Data())
    }
}
