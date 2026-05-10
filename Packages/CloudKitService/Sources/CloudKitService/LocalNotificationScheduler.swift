import Foundation
import UserNotifications

/// "Sıra sende" gibi yerel bildirimleri planlar.
/// Push tetikleyici cihaz tarafında çalıştığı için APNs server'a ihtiyaç yoktur.
public actor LocalNotificationScheduler {
    public enum AuthorizationStatus: Sendable, Equatable {
        case authorized
        case denied
        case provisional
        case notDetermined
        case ephemeral
    }

    public struct TurnNotification: Sendable, Equatable {
        public let matchCode: String
        public let title: String
        public let body: String

        public init(matchCode: String, title: String, body: String) {
            self.matchCode = matchCode
            self.title = title
            self.body = body
        }

        public static let identifierPrefix = "wordduel.turn."

        public var identifier: String { Self.identifierPrefix + matchCode }
    }

    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorizationStatus() async -> AuthorizationStatus {
        let settings = await center.notificationSettings()
        return Self.map(settings.authorizationStatus)
    }

    @discardableResult
    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func scheduleTurn(_ turn: TurnNotification, after seconds: TimeInterval = 1) async {
        let content = UNMutableNotificationContent()
        content.title = turn.title
        content.body = turn.body
        content.sound = .default
        content.userInfo = ["matchCode": turn.matchCode]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(0.1, seconds),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: turn.identifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    public func cancel(matchCode: String) {
        center.removePendingNotificationRequests(
            withIdentifiers: [TurnNotification.identifierPrefix + matchCode]
        )
        center.removeDeliveredNotifications(
            withIdentifiers: [TurnNotification.identifierPrefix + matchCode]
        )
    }

    public func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    nonisolated static func map(_ status: UNAuthorizationStatus) -> AuthorizationStatus {
        switch status {
        case .authorized: return .authorized
        case .denied: return .denied
        case .provisional: return .provisional
        case .notDetermined: return .notDetermined
        case .ephemeral: return .ephemeral
        @unknown default: return .notDetermined
        }
    }
}
