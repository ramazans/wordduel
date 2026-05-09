import Foundation

/// Saf Swift oyun motoru — SwiftData/UI bağımlılığı yok, deterministik test için.
/// Faz 3'te (yerel oyun mantığı) tam doldurulacak. Bu iskelet yalnızca tipleri
/// ve `Scoring`/`AnswerNormalizer` köprüsünü kurar.
public actor MatchEngine {
    public struct Config: Sendable {
        public let totalRounds: Int
        public let repeatInterval: Int
        public let initialWeight: Int

        public init(
            totalRounds: Int = 10,
            repeatInterval: Int = 3,
            initialWeight: Int = Scoring.initialWeight
        ) {
            self.totalRounds = totalRounds
            self.repeatInterval = repeatInterval
            self.initialWeight = initialWeight
        }
    }

    public struct PendingItem: Equatable, Sendable {
        public var word: String
        public var expectedAnswer: String
        public var dueAtRoundIndex: Int
        public var weight: Int
    }

    private let config: Config
    private var currentRoundIndex: Int = 0
    private var hostScore: Int = 0
    private var guestScore: Int = 0
    private var pending: [PendingItem] = []

    public init(config: Config = Config()) {
        self.config = config
    }

    public func snapshot() -> Snapshot {
        Snapshot(
            currentRoundIndex: currentRoundIndex,
            hostScore: hostScore,
            guestScore: guestScore,
            pending: pending,
            isFinished: currentRoundIndex >= config.totalRounds
        )
    }

    public struct Snapshot: Equatable, Sendable {
        public let currentRoundIndex: Int
        public let hostScore: Int
        public let guestScore: Int
        public let pending: [PendingItem]
        public let isFinished: Bool
    }

    /// Bir turun sonucunu işler. Faz 3'te genişletilecek; bu skelet sadece puan ve
    /// kuyruk akışının çalıştığını gösterir.
    public func resolve(
        word: String,
        expectedAnswer: String,
        answerGiven: String?,
        askerIsHost: Bool,
        existingWeight: Int? = nil
    ) -> RoundOutcome {
        let weight = existingWeight ?? config.initialWeight
        let verdict: AnswerNormalizer.AutoVerdict = {
            guard let answerGiven else { return .wrong }
            return AnswerNormalizer.autoJudge(answer: answerGiven, expected: expectedAnswer)
        }()

        let isCorrect: Bool
        switch verdict {
        case .correct: isCorrect = true
        case .wrong: isCorrect = false
        case .needsManualReview: isCorrect = false  // Faz 3'te manuel yönlendirme
        }

        var pointsAwarded = 0
        if !isCorrect {
            pointsAwarded = Scoring.points(forWeight: weight)
            if askerIsHost { hostScore += pointsAwarded } else { guestScore += pointsAwarded }
            if weight < Scoring.maxWeight {
                pending.append(
                    PendingItem(
                        word: word,
                        expectedAnswer: expectedAnswer,
                        dueAtRoundIndex: currentRoundIndex + config.repeatInterval,
                        weight: weight + 1
                    )
                )
            }
        } else {
            // Bilindi → kuyruktan düşer (mevcut item zaten resolve dışında, eklenmez)
        }

        currentRoundIndex += 1
        return RoundOutcome(
            verdict: verdict,
            pointsAwarded: pointsAwarded,
            newWeight: isCorrect ? nil : (weight < Scoring.maxWeight ? weight + 1 : nil)
        )
    }

    public struct RoundOutcome: Equatable, Sendable {
        public let verdict: AnswerNormalizer.AutoVerdict
        public let pointsAwarded: Int
        /// Kelime kuyrukta kaldıysa yeni weight; düştüyse nil.
        public let newWeight: Int?
    }

    public func dueRepeats() -> [PendingItem] {
        pending
            .filter { $0.dueAtRoundIndex <= currentRoundIndex }
            .sorted { $0.dueAtRoundIndex < $1.dueAtRoundIndex }
    }
}
