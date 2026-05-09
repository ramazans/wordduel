import Foundation
import SwiftData

@Model
public final class Match {
    @Attribute(.unique) public var code: String
    public var statusRaw: String
    public var totalRounds: Int
    public var repeatInterval: Int
    public var currentRoundIndex: Int
    public var hostScore: Int
    public var guestScore: Int
    public var roundTimerSeconds: Int
    public var createdAt: Date
    public var finishedAt: Date?

    public var host: Player?
    public var guest: Player?

    @Relationship(deleteRule: .cascade, inverse: \Round.match)
    public var rounds: [Round] = []

    public var pendingRepeatsData: Data

    public var status: MatchStatus {
        get { MatchStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    public var pendingRepeats: [PendingRepeatItem] {
        get {
            (try? JSONDecoder().decode([PendingRepeatItem].self, from: pendingRepeatsData)) ?? []
        }
        set {
            pendingRepeatsData = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
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
        self.pendingRepeatsData = Data("[]".utf8)
    }
}
