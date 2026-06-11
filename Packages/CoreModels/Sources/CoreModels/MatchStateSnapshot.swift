import Foundation
import SwiftData

/// Maçın cihazlar arası taşınabilir tam durumu. CloudKit public DB'ye
/// JSON olarak yazılır; karşı cihaz uygular. Append-only revizyon
/// zinciri: her mutasyon yeni bir revizyon kaydı üretir.
public struct MatchStateSnapshot: Codable, Sendable {
    public struct PlayerSnapshot: Codable, Sendable {
        public var appleUserID: String
        public var displayName: String
        public var avatarColor: Int

        public init(appleUserID: String, displayName: String, avatarColor: Int) {
            self.appleUserID = appleUserID
            self.displayName = displayName
            self.avatarColor = avatarColor
        }

        public init?(player: Player?) {
            guard let player else { return nil }
            self.appleUserID = player.appleUserID
            self.displayName = player.displayName
            self.avatarColor = player.avatarColor
        }
    }

    public struct RoundSnapshot: Codable, Sendable {
        public var index: Int
        public var askerRoleRaw: String
        public var word: String
        public var expectedAnswer: String
        public var answerGiven: String?
        public var judgementRaw: String
        public var pointsAwarded: Int
        public var isRepeat: Bool
        public var originRoundIndex: Int?
        public var startedAt: Date?
        public var resolvedAt: Date?

        public init(round: Round) {
            self.index = round.index
            self.askerRoleRaw = round.askerRoleRaw
            self.word = round.word
            self.expectedAnswer = round.expectedAnswer
            self.answerGiven = round.answerGiven
            self.judgementRaw = round.judgementRaw
            self.pointsAwarded = round.pointsAwarded
            self.isRepeat = round.isRepeat
            self.originRoundIndex = round.originRoundIndex
            self.startedAt = round.startedAt
            self.resolvedAt = round.resolvedAt
        }
    }

    public var revision: Int
    public var code: String
    public var statusRaw: String
    public var totalRounds: Int
    public var repeatInterval: Int
    public var currentRoundIndex: Int
    public var hostScore: Int
    public var guestScore: Int
    public var roundTimerSeconds: Int
    public var createdAt: Date
    public var finishedAt: Date?
    public var pendingRepeats: [PendingRepeatItem]
    public var host: PlayerSnapshot?
    public var guest: PlayerSnapshot?
    public var rounds: [RoundSnapshot]

    @MainActor
    public init(match: Match, revision: Int) {
        self.revision = revision
        self.code = match.code
        self.statusRaw = match.statusRaw
        self.totalRounds = match.totalRounds
        self.repeatInterval = match.repeatInterval
        self.currentRoundIndex = match.currentRoundIndex
        self.hostScore = match.hostScore
        self.guestScore = match.guestScore
        self.roundTimerSeconds = match.roundTimerSeconds
        self.createdAt = match.createdAt
        self.finishedAt = match.finishedAt
        self.pendingRepeats = match.pendingRepeats
        self.host = PlayerSnapshot(player: match.host)
        self.guest = PlayerSnapshot(player: match.guest)
        self.rounds = (match.rounds ?? []).map(RoundSnapshot.init)
    }

    // MARK: - Uygulama

    /// Uzak durumu yerel modele uygular. Oyuncular `appleUserID` ile
    /// upsert edilir, turlar index üzerinden uzlaştırılır.
    @MainActor
    public func apply(to match: Match, in context: ModelContext) {
        match.statusRaw = statusRaw
        match.totalRounds = totalRounds
        match.repeatInterval = repeatInterval
        match.currentRoundIndex = currentRoundIndex
        match.hostScore = hostScore
        match.guestScore = guestScore
        match.roundTimerSeconds = roundTimerSeconds
        match.createdAt = createdAt
        match.finishedAt = finishedAt
        match.pendingRepeats = pendingRepeats
        match.syncRevision = revision

        if let host {
            match.host = upsertPlayer(host, in: context)
        }
        if let guest {
            match.guest = upsertPlayer(guest, in: context)
        }

        var localRounds = match.rounds ?? []
        for snapshot in rounds {
            if let existing = localRounds.first(where: { $0.index == snapshot.index }) {
                existing.askerRoleRaw = snapshot.askerRoleRaw
                existing.word = snapshot.word
                existing.expectedAnswer = snapshot.expectedAnswer
                existing.answerGiven = snapshot.answerGiven
                existing.judgementRaw = snapshot.judgementRaw
                existing.pointsAwarded = snapshot.pointsAwarded
                existing.isRepeat = snapshot.isRepeat
                existing.originRoundIndex = snapshot.originRoundIndex
                existing.startedAt = snapshot.startedAt
                existing.resolvedAt = snapshot.resolvedAt
            } else {
                let round = Round(
                    index: snapshot.index,
                    askerRole: AskerRole(rawValue: snapshot.askerRoleRaw) ?? .host,
                    word: snapshot.word,
                    expectedAnswer: snapshot.expectedAnswer,
                    isRepeat: snapshot.isRepeat,
                    originRoundIndex: snapshot.originRoundIndex
                )
                round.answerGiven = snapshot.answerGiven
                round.judgementRaw = snapshot.judgementRaw
                round.pointsAwarded = snapshot.pointsAwarded
                round.startedAt = snapshot.startedAt
                round.resolvedAt = snapshot.resolvedAt
                localRounds.append(round)
            }
        }
        match.rounds = localRounds
    }

    @MainActor
    private func upsertPlayer(_ snapshot: PlayerSnapshot, in context: ModelContext) -> Player {
        let id = snapshot.appleUserID
        var descriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.appleUserID == id }
        )
        descriptor.fetchLimit = 1

        if let existing = try? context.fetch(descriptor).first, let existing {
            if existing.displayName.isEmpty, !snapshot.displayName.isEmpty {
                existing.displayName = snapshot.displayName
            }
            return existing
        }

        let player = Player(
            appleUserID: snapshot.appleUserID,
            displayName: snapshot.displayName,
            avatarColor: snapshot.avatarColor
        )
        context.insert(player)
        return player
    }

    // MARK: - Kodlama

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> MatchStateSnapshot {
        try JSONDecoder().decode(MatchStateSnapshot.self, from: data)
    }
}
