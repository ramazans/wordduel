import Foundation
import CoreModels
import MatchEngine

/// Kalıcı `Match`/`Round` modeli üzerinde MatchEngine kurallarını uygulayan akış
/// katmanı. Saf durum makinesi (`MatchEngine` aktörü) test edilebilir referans;
/// burada aynı kurallar SwiftData'da yaşayan duruma uygulanır ki CloudKit her iki
/// cihaza da senkronize edebilsin.
///
/// Kurallar (README ile birebir):
/// - Çift indeksli turları host, tekleri guest sorar.
/// - Cevap `AnswerNormalizer.autoJudge` ile otomatik karara bağlanır;
///   karar verilemiyorsa asker manuel değerlendirir.
/// - Yanlış cevap askere `Scoring.points(forWeight:)` puanı kazandırır
///   (2 → 4 → 8) ve kelime `repeatInterval` tur sonrasına yeniden kuyruklanır.
/// - Doğru bilinen kelime kuyruktan düşer, puan yazılmaz.
@MainActor
struct MatchFlow {
    let match: Match

    enum Phase: Equatable {
        /// Guest henüz davete katılmadı.
        case waitingForOpponent
        /// Sıradaki tur için kelime seçiliyor.
        case picking(asker: AskerRole)
        /// Kelime soruldu, cevap bekleniyor.
        case answering
        /// Cevap verildi, asker manuel değerlendiriyor.
        case reviewing
        case finished
    }

    /// Cevap süresi dolduktan sonra asker'in turu tek taraflı kapatabilmesi
    /// için tanınan pay (saat kaymaları ve ağ gecikmesi için).
    static let timeoutGrace: TimeInterval = 10

    static func asker(forRoundIndex index: Int) -> AskerRole {
        index % 2 == 0 ? .host : .guest
    }

    // MARK: - Durum okuma

    var currentRound: Round? {
        match.rounds.first { $0.index == match.currentRoundIndex }
    }

    var lastResolvedRound: Round? {
        match.rounds
            .filter { $0.judgement != .pendingReview }
            .max { ($0.resolvedAt ?? .distantPast) < ($1.resolvedAt ?? .distantPast) }
    }

    var phase: Phase {
        if match.status == .finished { return .finished }
        if match.status == .pending || match.guest == nil { return .waitingForOpponent }
        guard let round = currentRound else {
            return .picking(asker: Self.asker(forRoundIndex: match.currentRoundIndex))
        }
        if round.judgement == .pendingReview {
            return round.answerGiven == nil ? .answering : .reviewing
        }
        // Çözülmüş tur her zaman index'i ilerletir; buraya düşmek senkronizasyon
        // yarışı demektir — güvenli taraf: yeni kelime seçimi.
        return .picking(asker: Self.asker(forRoundIndex: match.currentRoundIndex))
    }

    /// Bu rolün vakti gelmiş tekrarları. Bir kelimeyi yalnızca onu ilk soran
    /// taraf yeniden sorabilir (cevaplayamayan hep aynı oyuncudur).
    func dueRepeats(for role: AskerRole) -> [PendingRepeatItem] {
        match.pendingRepeats
            .filter { item in
                item.dueAtRoundIndex <= match.currentRoundIndex &&
                originRound(forWord: item.word)?.askerRole == role
            }
            .sorted { $0.dueAtRoundIndex < $1.dueAtRoundIndex }
    }

    /// Asker tarafında, cevaplayanın cihazı kapalıyken turu kapatma hakkı.
    func answerDeadlinePassed(now: Date = .now) -> Bool {
        guard let round = currentRound,
              round.judgement == .pendingReview,
              round.answerGiven == nil,
              let startedAt = round.startedAt else { return false }
        return now.timeIntervalSince(startedAt) > Double(match.roundTimerSeconds) + Self.timeoutGrace
    }

    private func originRound(forWord word: String) -> Round? {
        match.rounds
            .filter { $0.word == word }
            .max { $0.index < $1.index }
    }

    // MARK: - Geçişler

    func askWord(_ word: String, expectedAnswer: String, asker: AskerRole) {
        guard case .picking(let expected) = phase, expected == asker else { return }
        let round = Round(
            index: match.currentRoundIndex,
            askerRole: asker,
            word: word,
            expectedAnswer: expectedAnswer
        )
        round.startedAt = .now
        match.rounds.append(round)
    }

    func askRepeat(_ item: PendingRepeatItem, asker: AskerRole) {
        guard case .picking(let expected) = phase, expected == asker else { return }
        let round = Round(
            index: match.currentRoundIndex,
            askerRole: asker,
            word: item.word,
            expectedAnswer: item.expectedAnswer,
            isRepeat: true,
            originRoundIndex: originRound(forWord: item.word)?.index
        )
        round.startedAt = .now
        match.rounds.append(round)
    }

    /// Cevabı işler. Boş cevap = süre doldu / bilmiyorum → yanlış.
    /// Otomatik karar verilemiyorsa tur asker'in değerlendirmesine kalır.
    func submitAnswer(_ answer: String) {
        guard let round = currentRound,
              round.judgement == .pendingReview,
              round.answerGiven == nil else { return }

        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            resolve(round, isCorrect: false)
            return
        }

        round.answerGiven = trimmed
        switch AnswerNormalizer.autoJudge(answer: trimmed, expected: round.expectedAnswer) {
        case .correct:
            resolve(round, isCorrect: true)
        case .wrong:
            resolve(round, isCorrect: false)
        case .needsManualReview:
            break
        }
    }

    /// Asker'in manuel kararı (yalnızca cevap verilmiş, bekleyen turda).
    func review(isCorrect: Bool) {
        guard let round = currentRound,
              round.judgement == .pendingReview,
              round.answerGiven != nil else { return }
        resolve(round, isCorrect: isCorrect)
    }

    /// Süre + pay dolduysa asker turu cevapsız (yanlış) kapatır.
    func resolveTimeout() {
        guard answerDeadlinePassed(), let round = currentRound else { return }
        resolve(round, isCorrect: false)
    }

    /// Davet kabul eden taraf, paylaşılan maç kaydı cihazına ulaştığında
    /// guest koltuğunu kapar ve maçı başlatır.
    static func claimGuestSeatIfNeeded(match: Match, me: Player, myAppleUserID: String) {
        guard match.status == .pending,
              match.guest == nil,
              let host = match.host,
              host.appleUserID != myAppleUserID,
              me.appleUserID == myAppleUserID else { return }
        match.guest = me
        match.status = .active
    }

    // MARK: - Çözümleme

    private func resolve(_ round: Round, isCorrect: Bool) {
        let weight = currentWeight(of: round)
        round.judgement = isCorrect ? .correct : .wrong
        round.resolvedAt = .now

        var queue = match.pendingRepeats
        queue.removeAll { $0.word == round.word }

        if isCorrect {
            round.pointsAwarded = 0
        } else {
            let points = Scoring.points(forWeight: weight)
            round.pointsAwarded = points
            switch round.askerRole {
            case .host: match.hostScore += points
            case .guest: match.guestScore += points
            }
            if weight < Scoring.maxWeight {
                queue.append(
                    PendingRepeatItem(
                        word: round.word,
                        expectedAnswer: round.expectedAnswer,
                        dueAtRoundIndex: match.currentRoundIndex + match.repeatInterval,
                        weight: weight + 1
                    )
                )
            }
        }
        match.pendingRepeats = queue

        match.currentRoundIndex += 1
        if match.currentRoundIndex >= match.totalRounds {
            match.status = .finished
            match.finishedAt = .now
        }
    }

    /// Tekrar turunun ağırlığı kuyruktaki kayıttan okunur; taze kelime hep 1.
    private func currentWeight(of round: Round) -> Int {
        guard round.isRepeat else { return Scoring.initialWeight }
        return match.pendingRepeats.first { $0.word == round.word }?.weight
            ?? Scoring.initialWeight
    }
}
