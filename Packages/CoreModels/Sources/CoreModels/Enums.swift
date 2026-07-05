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

/// Sorulan içeriğin türü. Motor kurallarını etkilemez; içerik seçimi,
/// rozetler ve şık havuzu filtrelemesi için kullanılır.
public enum ContentKind: String, Codable, Sendable, CaseIterable {
    case word
    case idiom
    case phrasal
}

/// Bir turun cevap formatı: serbest metin veya çoktan seçmeli (4 şık).
public enum AnswerFormat: String, Codable, Sendable, CaseIterable {
    case text
    case multipleChoice
}

public struct PendingRepeatItem: Codable, Hashable, Sendable {
    public var word: String
    public var expectedAnswer: String
    public var dueAtRoundIndex: Int
    public var weight: Int
    public var kindRaw: String

    public var kind: ContentKind {
        ContentKind(rawValue: kindRaw) ?? .word
    }

    public init(
        word: String,
        expectedAnswer: String,
        dueAtRoundIndex: Int,
        weight: Int,
        kindRaw: String = ContentKind.word.rawValue
    ) {
        self.word = word
        self.expectedAnswer = expectedAnswer
        self.dueAtRoundIndex = dueAtRoundIndex
        self.weight = weight
        self.kindRaw = kindRaw
    }

    // Eski istemcilerin yazdığı JSON'da `kindRaw` yok — decode'da "word"
    // varsayılır ki mevcut kuyruklar ve snapshot'lar bozulmasın.
    private enum CodingKeys: String, CodingKey {
        case word, expectedAnswer, dueAtRoundIndex, weight, kindRaw
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        expectedAnswer = try container.decode(String.self, forKey: .expectedAnswer)
        dueAtRoundIndex = try container.decode(Int.self, forKey: .dueAtRoundIndex)
        weight = try container.decode(Int.self, forKey: .weight)
        kindRaw = try container.decodeIfPresent(String.self, forKey: .kindRaw)
            ?? ContentKind.word.rawValue
    }
}
