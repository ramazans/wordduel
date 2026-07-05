import Foundation

/// Saf Swift oyun motoru. Bir maçın durum makinesini, puanlamayı ve tekrar
/// kuyruğunu yönetir. SwiftData/UI bağımlılığı yoktur — Linux/macOS CLI'da
/// `swift test` ile çalıştırılabilir.
///
/// Durum akışı:
/// ```
/// .idle → askWord(...) → .answering
/// .answering → submitAnswer(...)
///              → autoVerdict == .needsManualReview → .manualReview
///              → autoVerdict ∈ {.correct, .wrong}   → .reviewed
/// .manualReview → confirmManual(isCorrect:) → .reviewed
/// .reviewed → advance() → .idle (or .finished if last round)
/// ```
public actor MatchEngine {
    // MARK: - Types

    public struct Config: Sendable, Equatable {
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

    public enum AskerRole: String, Sendable, Equatable, CaseIterable {
        case host
        case guest

        public var opponent: AskerRole {
            self == .host ? .guest : .host
        }
    }

    public enum Phase: Sendable, Equatable {
        case idle
        case answering
        case manualReview
        case reviewed
        case finished
    }

    public enum Winner: Sendable, Equatable {
        case host
        case guest
        case tie
    }

    /// Cevap formatı. CoreModels'teki `AnswerFormat` ile bilinçli olarak
    /// kopya (paketler ayrık — `AskerRole` gibi). İçerik türü (kelime/deyim/
    /// phrasal) motora girmez; kuralları etkilemez.
    public enum AnswerFormat: String, Sendable, Equatable {
        case text
        case multipleChoice
    }

    public struct PendingItem: Sendable, Equatable, Hashable {
        public let word: String
        public let expectedAnswer: String
        public let dueAtRoundIndex: Int
        public let weight: Int

        public init(word: String, expectedAnswer: String, dueAtRoundIndex: Int, weight: Int) {
            self.word = word
            self.expectedAnswer = expectedAnswer
            self.dueAtRoundIndex = dueAtRoundIndex
            self.weight = weight
        }
    }

    public struct ActiveRound: Sendable, Equatable {
        public let index: Int
        public let asker: AskerRole
        public let word: String
        public let expectedAnswer: String
        public let weight: Int
        public let isRepeat: Bool
        public let originIndex: Int?
        public let format: AnswerFormat
        /// Çoktan seçmeli turda gösterilen şıklar (doğru cevap dahil, karışık).
        public let options: [String]
        public var answerGiven: String?
        public var autoVerdict: AnswerNormalizer.AutoVerdict?
    }

    public struct Snapshot: Sendable, Equatable {
        public let phase: Phase
        public let currentRoundIndex: Int
        public let totalRounds: Int
        public let hostScore: Int
        public let guestScore: Int
        public let pending: [PendingItem]
        public let activeRound: ActiveRound?
        public let winner: Winner?
    }

    public enum EngineError: Error, Sendable, Equatable {
        case wrongPhase(expected: Phase, actual: Phase)
        case matchFinished
        case repeatNotInQueue
    }

    public struct LastResolution: Sendable, Equatable {
        public let isCorrect: Bool
        public let pointsAwarded: Int
        public let asker: AskerRole
        public let word: String
        /// `nil` ise kuyruktan düştü (correct, ya da maxWeight'te wrong).
        public let nextWeight: Int?
    }

    // MARK: - State

    private let config: Config
    private var phase: Phase = .idle
    private var currentRoundIndex: Int = 0
    private var hostScore: Int = 0
    private var guestScore: Int = 0
    private var pending: [PendingItem] = []
    private var activeRound: ActiveRound?
    private var lastResolution: LastResolution?

    // MARK: - Init

    public init(config: Config = Config()) {
        self.config = config
    }

    // MARK: - Read

    public func snapshot() -> Snapshot {
        Snapshot(
            phase: phase,
            currentRoundIndex: currentRoundIndex,
            totalRounds: config.totalRounds,
            hostScore: hostScore,
            guestScore: guestScore,
            pending: pending,
            activeRound: activeRound,
            winner: phase == .finished ? computeWinner() : nil
        )
    }

    public func currentPhase() -> Phase { phase }
    public func scores() -> (host: Int, guest: Int) { (hostScore, guestScore) }
    public func lastResolved() -> LastResolution? { lastResolution }

    /// Kuyrukta vakti gelmiş tekrarlar (önce en eski due).
    public func dueRepeats() -> [PendingItem] {
        pending
            .filter { $0.dueAtRoundIndex <= currentRoundIndex }
            .sorted { $0.dueAtRoundIndex < $1.dueAtRoundIndex }
    }

    // MARK: - Transitions

    /// Asker yeni bir kelime sorar (kuyrukta olmayan, taze). Yalnızca `.idle`'da çalışır.
    public func askWord(
        _ word: String,
        expectedAnswer: String,
        asker: AskerRole,
        format: AnswerFormat = .text,
        options: [String] = []
    ) throws {
        try requirePhase(.idle)
        try startRound(
            word: word,
            expectedAnswer: expectedAnswer,
            asker: asker,
            weight: config.initialWeight,
            isRepeat: false,
            originIndex: nil,
            format: format,
            options: options
        )
    }

    /// Kuyruktan bir tekrarı tüketip o kelimeyi sorar. Yalnızca `.idle`'da çalışır.
    /// Format yeniden sorarken seçilir; şıklar taze üretilip verilir (kuyrukta saklanmaz).
    /// - Throws: `EngineError.repeatNotInQueue` eğer item kuyrukta değilse.
    public func askRepeat(
        _ item: PendingItem,
        asker: AskerRole,
        originIndex: Int? = nil,
        format: AnswerFormat = .text,
        options: [String] = []
    ) throws {
        try requirePhase(.idle)
        guard let idx = pending.firstIndex(of: item) else {
            throw EngineError.repeatNotInQueue
        }
        pending.remove(at: idx)
        try startRound(
            word: item.word,
            expectedAnswer: item.expectedAnswer,
            asker: asker,
            weight: item.weight,
            isRepeat: true,
            originIndex: originIndex,
            format: format,
            options: options
        )
    }

    private func startRound(
        word: String,
        expectedAnswer: String,
        asker: AskerRole,
        weight: Int,
        isRepeat: Bool,
        originIndex: Int?,
        format: AnswerFormat,
        options: [String]
    ) throws {
        activeRound = ActiveRound(
            index: currentRoundIndex,
            asker: asker,
            word: word,
            expectedAnswer: expectedAnswer,
            weight: weight,
            isRepeat: isRepeat,
            originIndex: originIndex,
            format: format,
            options: options,
            answerGiven: nil,
            autoVerdict: nil
        )
        phase = .answering
    }

    /// Cevap verilir. `nil` veya boş string → timeout / "bilmedim".
    /// - Returns: otomatik karar. `.needsManualReview` ise asker `confirmManual` çağırmalı.
    @discardableResult
    public func submitAnswer(_ answer: String?) throws -> AnswerNormalizer.AutoVerdict {
        try requirePhase(.answering)
        guard var round = activeRound else { throw EngineError.wrongPhase(expected: .answering, actual: phase) }

        let trimmed = (answer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let verdict: AnswerNormalizer.AutoVerdict
        if trimmed.isEmpty {
            verdict = .wrong
        } else if round.format == .multipleChoice {
            // Şık dokunuşu yazım hatası olamaz: tam eşitlik, manuel inceleme yok.
            verdict = AnswerNormalizer.normalize(trimmed) == AnswerNormalizer.normalize(round.expectedAnswer)
                ? .correct : .wrong
        } else {
            verdict = AnswerNormalizer.autoJudge(answer: trimmed, expected: round.expectedAnswer)
        }

        round.answerGiven = trimmed.isEmpty ? nil : trimmed
        round.autoVerdict = verdict
        activeRound = round

        switch verdict {
        case .correct:
            applyResolution(isCorrect: true)
        case .wrong:
            applyResolution(isCorrect: false)
        case .needsManualReview:
            phase = .manualReview
        }

        return verdict
    }

    /// Asker manuel kararı verir (yalnızca `.manualReview` aşamasında).
    public func confirmManual(isCorrect: Bool) throws {
        try requirePhase(.manualReview)
        applyResolution(isCorrect: isCorrect)
    }

    /// Çözülmüş tur sonrası bir sonraki tura geçer. Son tur ise `.finished`.
    public func advance() throws {
        try requirePhase(.reviewed)
        currentRoundIndex += 1
        activeRound = nil
        if currentRoundIndex >= config.totalRounds {
            phase = .finished
        } else {
            phase = .idle
        }
    }

    /// Kuyruktan bir tekrar tüketir (asker bu kelimeyi sormak istediğinde).
    /// `askWord(...)` öncesi çağrılır; sonra weight ile birlikte askWord yapılır.
    public func consumeRepeat(_ item: PendingItem) throws {
        guard let idx = pending.firstIndex(of: item) else {
            throw EngineError.repeatNotInQueue
        }
        pending.remove(at: idx)
    }

    // MARK: - Internals

    private func applyResolution(isCorrect: Bool) {
        guard let round = activeRound else { return }

        var pointsAwarded = 0
        var nextWeight: Int? = nil

        if isCorrect {
            // Doğru → puan yok. Kuyrukta varsa zaten consumeRepeat ile çıkmıştı.
            // (consumeRepeat olmadan da bilinen bir kelime tekrar aktif olamaz.)
        } else {
            pointsAwarded = Scoring.points(forWeight: round.weight)
            switch round.asker {
            case .host: hostScore += pointsAwarded
            case .guest: guestScore += pointsAwarded
            }
            if round.weight < Scoring.maxWeight {
                let next = round.weight + 1
                nextWeight = next
                pending.append(
                    PendingItem(
                        word: round.word,
                        expectedAnswer: round.expectedAnswer,
                        dueAtRoundIndex: currentRoundIndex + config.repeatInterval,
                        weight: next
                    )
                )
            }
        }

        lastResolution = LastResolution(
            isCorrect: isCorrect,
            pointsAwarded: pointsAwarded,
            asker: round.asker,
            word: round.word,
            nextWeight: nextWeight
        )
        phase = .reviewed
    }

    private func requirePhase(_ expected: Phase) throws {
        guard phase == expected else {
            if phase == .finished { throw EngineError.matchFinished }
            throw EngineError.wrongPhase(expected: expected, actual: phase)
        }
    }

    private func computeWinner() -> Winner {
        if hostScore > guestScore { return .host }
        if guestScore > hostScore { return .guest }
        return .tie
    }
}
