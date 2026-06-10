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
}
