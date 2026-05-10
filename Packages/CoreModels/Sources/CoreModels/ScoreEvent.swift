import Foundation
import SwiftData

@Model
public final class ScoreEvent {
    public var matchID: String
    public var roundIndex: Int
    public var playerID: String
    public var delta: Int
    public var reasonRaw: String
    public var createdAt: Date

    public var reason: ScoreReason {
        get { ScoreReason(rawValue: reasonRaw) ?? .autoCorrect }
        set { reasonRaw = newValue.rawValue }
    }

    public init(
        matchID: String,
        roundIndex: Int,
        playerID: String,
        delta: Int,
        reason: ScoreReason,
        createdAt: Date = .now
    ) {
        self.matchID = matchID
        self.roundIndex = roundIndex
        self.playerID = playerID
        self.delta = delta
        self.reasonRaw = reason.rawValue
        self.createdAt = createdAt
    }
}
