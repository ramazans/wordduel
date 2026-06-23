import Foundation
import CoreModels

/// Maçlara "benim" perspektifimden bakan yardımcı: rol, rakip, skor ve sonuç.
/// Home, Profil ve Geçmiş ekranları aynı mantığı paylaşır.
struct MatchStats {
    enum Outcome {
        case win, loss, draw
    }

    let myAppleUserID: String?

    func role(in match: Match) -> AskerRole? {
        guard let myAppleUserID else { return nil }
        if match.host?.appleUserID == myAppleUserID { return .host }
        if match.guest?.appleUserID == myAppleUserID { return .guest }
        return nil
    }

    func opponent(in match: Match) -> Player? {
        switch role(in: match) {
        case .host: return match.guest
        case .guest: return match.host
        case nil: return nil
        }
    }

    func myScore(in match: Match) -> Int {
        role(in: match) == .guest ? match.guestScore : match.hostScore
    }

    func opponentScore(in match: Match) -> Int {
        role(in: match) == .guest ? match.hostScore : match.guestScore
    }

    func outcome(of match: Match) -> Outcome {
        let mine = myScore(in: match)
        let theirs = opponentScore(in: match)
        if mine > theirs { return .win }
        if mine < theirs { return .loss }
        return .draw
    }

    /// Bitmiş maçlardan galibiyet/beraberlik/mağlubiyet dökümü.
    func record(for matches: [Match]) -> (wins: Int, draws: Int, losses: Int) {
        var wins = 0, draws = 0, losses = 0
        for match in matches where match.status == .finished {
            switch outcome(of: match) {
            case .win: wins += 1
            case .draw: draws += 1
            case .loss: losses += 1
            }
        }
        return (wins, draws, losses)
    }

    /// Tek bir rakiple kafa kafaya dökümü. `wins` benim, `losses` rakibin
    /// galibiyetleri. `lastPlayed` o rakiple oynanan en son maçın tarihidir.
    struct RivalRecord: Identifiable {
        let opponent: Player
        let wins: Int
        let draws: Int
        let losses: Int
        let lastPlayed: Date
        var id: String { opponent.appleUserID }
    }

    /// Rakip bazında kafa kafaya dökümler — en son oynanan rakip başta.
    /// Skorlar yalnızca bitmiş maçlardan sayılır; sıralama ise rakiple olan
    /// herhangi bir maçın (aktif/bitmiş) en yeni tarihine göredir.
    func rivals(from matches: [Match]) -> [RivalRecord] {
        struct Accumulator {
            var opponent: Player
            var wins = 0
            var draws = 0
            var losses = 0
            var lastPlayed: Date
        }

        var grouped: [String: Accumulator] = [:]
        var order: [String] = []

        for match in matches {
            guard let opponent = opponent(in: match) else { continue }
            let key = opponent.appleUserID
            let date = match.finishedAt ?? match.createdAt

            var entry = grouped[key]
            if entry == nil {
                entry = Accumulator(opponent: opponent, lastPlayed: date)
                order.append(key)
            }
            entry!.lastPlayed = max(entry!.lastPlayed, date)

            if match.status == .finished {
                switch outcome(of: match) {
                case .win: entry!.wins += 1
                case .draw: entry!.draws += 1
                case .loss: entry!.losses += 1
                }
            }
            grouped[key] = entry
        }

        return order
            .compactMap { grouped[$0] }
            .map {
                RivalRecord(
                    opponent: $0.opponent,
                    wins: $0.wins,
                    draws: $0.draws,
                    losses: $0.losses,
                    lastPlayed: $0.lastPlayed
                )
            }
            .sorted { $0.lastPlayed > $1.lastPlayed }
    }
}
