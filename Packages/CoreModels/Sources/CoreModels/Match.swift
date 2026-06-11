import Foundation
import SwiftData

@Model
public final class Match {
    public var code: String = ""
    public var statusRaw: String = "pending"
    public var totalRounds: Int = 10
    public var repeatInterval: Int = 3
    public var currentRoundIndex: Int = 0
    public var hostScore: Int = 0
    public var guestScore: Int = 0
    public var roundTimerSeconds: Int = 30
    public var createdAt: Date = Date()
    public var finishedAt: Date?

    public var host: Player?
    public var guest: Player?

    @Relationship(deleteRule: .cascade, inverse: \Round.match)
    public var rounds: [Round]? = nil

    public var pendingRepeatsData: Data = Data()

    /// Cihazlar arası senkronda uygulanan son durum revizyonu.
    /// Her yerel mutasyon push'ta +1 artar; pull yalnızca daha yüksek
    /// revizyonlu uzak durumu uygular.
    public var syncRevision: Int = 0

    public var status: MatchStatus {
        get { MatchStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    public var pendingRepeats: [PendingRepeatItem] {
        get {
            guard !pendingRepeatsData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([PendingRepeatItem].self, from: pendingRepeatsData)) ?? []
        }
        set {
            pendingRepeatsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    public init(
        code: String,
        host: Player? = nil,
        totalRounds: Int = 10,
        repeatInterval: Int = 3,
        roundTimerSeconds: Int = 30
    ) {
        self.code = code
        self.statusRaw = MatchStatus.pending.rawValue
        self.totalRounds = totalRounds
        self.repeatInterval = repeatInterval
        self.currentRoundIndex = 0
        self.hostScore = 0
        self.guestScore = 0
        self.roundTimerSeconds = roundTimerSeconds
        self.createdAt = .now
        self.host = host
        self.pendingRepeatsData = Data()
    }
}
