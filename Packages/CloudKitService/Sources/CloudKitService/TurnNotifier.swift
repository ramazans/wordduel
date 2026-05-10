import Foundation

/// "Sıra sende" bildirimini ne zaman atması gerektiğine karar veren saf-Swift köprü.
/// View katmanı SwiftData değişikliklerini izleyip aktif maçları bu yardımcıya
/// geçirir; bildirimler `LocalNotificationScheduler` üzerinden planlanır.
public struct TurnNotifier: Sendable {
    public struct ActiveMatch: Sendable, Equatable {
        public let code: String
        public let isMyTurnToAnswer: Bool
        public let opponentDisplayName: String

        public init(code: String, isMyTurnToAnswer: Bool, opponentDisplayName: String) {
            self.code = code
            self.isMyTurnToAnswer = isMyTurnToAnswer
            self.opponentDisplayName = opponentDisplayName
        }
    }

    public init() {}

    /// Aktif maçlardan sıra sendeyse `TurnNotification` üretir.
    public func notifications(
        for matches: [ActiveMatch],
        titleFor: (ActiveMatch) -> String = Self.defaultTitle,
        bodyFor: (ActiveMatch) -> String = Self.defaultBody
    ) -> [LocalNotificationScheduler.TurnNotification] {
        matches
            .filter { $0.isMyTurnToAnswer }
            .map { match in
                LocalNotificationScheduler.TurnNotification(
                    matchCode: match.code,
                    title: titleFor(match),
                    body: bodyFor(match)
                )
            }
    }

    public static func defaultTitle(_ match: ActiveMatch) -> String {
        "Sıra sende"
    }

    public static func defaultBody(_ match: ActiveMatch) -> String {
        "\(match.opponentDisplayName) bir kelime sordu. Maç \(match.code)."
    }
}
