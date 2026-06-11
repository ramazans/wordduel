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
    public let cloudKitEnabled: Bool

    /// Push'tan gelen güncellemeleri view'lar bu stream'i dinleyebilir.
    public let pushUpdates: AsyncStream<PushNotificationHandler.Outcome>
    private let pushContinuation: AsyncStream<PushNotificationHandler.Outcome>.Continuation

    public init(cloudKitContainerID: String, cloudKitEnabled: Bool) {
        self.cloudKitEnabled = cloudKitEnabled
        let container = CKContainer(identifier: cloudKitContainerID)
        self.matchSyncService = MatchSyncService(containerIdentifier: cloudKitContainerID)
        self.subscriptionManager = SubscriptionManager(container: container)
        self.notificationScheduler = LocalNotificationScheduler()

        var continuation: AsyncStream<PushNotificationHandler.Outcome>.Continuation!
        self.pushUpdates = AsyncStream { continuation = $0 }
        self.pushContinuation = continuation
    }

    public func handlePushOutcome(_ outcome: PushNotificationHandler.Outcome) {
        pushContinuation.yield(outcome)
    }

    public func bootstrap() async {
        guard cloudKitEnabled else { return }
        do {
            try await subscriptionManager.ensureRegistered()
        } catch {
            // Subscription kurulumu kritik değil — UI yine de çalışır.
        }
    }
}
