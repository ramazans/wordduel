import Foundation
import Observation
import CloudKit
import CloudKitService

/// Uygulama düzeyinde paylaşılan servisler. Environment üzerinden view'lara geçer.
@Observable
@MainActor
public final class AppServices {
    public let matchSyncService: MatchSyncService
    public let subscriptionManager: SubscriptionManager
    public let notificationScheduler: LocalNotificationScheduler

    /// Push'tan gelen güncellemeleri view'lar bu stream'i dinleyebilir.
    public let pushUpdates: AsyncStream<PushNotificationHandler.Outcome>
    private let pushContinuation: AsyncStream<PushNotificationHandler.Outcome>.Continuation

    public init(cloudKitContainerID: String) {
        let container = CKContainer(identifier: cloudKitContainerID)
        self.matchSyncService = MatchSyncService(containerIdentifier: cloudKitContainerID)
        self.subscriptionManager = SubscriptionManager(container: container)
        self.notificationScheduler = LocalNotificationScheduler()

        var continuation: AsyncStream<PushNotificationHandler.Outcome>.Continuation!
        self.pushUpdates = AsyncStream { continuation = $0 }
        self.pushContinuation = continuation
    }

    /// AppDelegate'in çağıracağı sink — push event'i AsyncStream'e iletir.
    public func handlePushOutcome(_ outcome: PushNotificationHandler.Outcome) {
        pushContinuation.yield(outcome)
    }

    /// Uygulama açılışında (auth sonrası) çağrılır.
    public func bootstrap() async {
        do {
            try await subscriptionManager.ensureRegistered()
        } catch {
            // Subscription kurulumu kritik değil — UI yine de çalışır.
        }
    }
}
