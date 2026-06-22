import Foundation
import CloudKit

/// CloudKit push subscription'larını idempotent olarak kurar/kaldırır.
/// Idempotency: kayıt id'leri UserDefaults'ta tutulur — uygulama yeniden açılışında
/// aynı subscription tekrar oluşturulmaya çalışılmaz.
public actor SubscriptionManager {
    public enum SubscriptionError: Error, Sendable, Equatable {
        case underlying(String)
    }

    public enum Scope: String, Sendable, CaseIterable {
        case privateDB = "wordduel.privateDB.subscription"
        case sharedDB = "wordduel.sharedDB.subscription"
        case publicDB = "wordduel.publicDB.matchState.subscription"
    }

    private let container: CKContainer
    private let userDefaults: UserDefaults
    private let storageKey = "wordduel.installedSubscriptions"

    public init(container: CKContainer, userDefaults: UserDefaults = .standard) {
        self.container = container
        self.userDefaults = userDefaults
    }

    public func ensureRegistered() async throws {
        let installed = installedScopes()

        if !installed.contains(.privateDB) {
            try await register(scope: .privateDB, in: container.privateCloudDatabase)
            mark(.privateDB, installed: true)
        }
        if !installed.contains(.sharedDB) {
            try await register(scope: .sharedDB, in: container.sharedCloudDatabase)
            mark(.sharedDB, installed: true)
        }
        if !installed.contains(.publicDB) {
            try await registerPublicMatchState()
            mark(.publicDB, installed: true)
        }
    }

    public func unregisterAll() async throws {
        for scope in Scope.allCases {
            let database: CKDatabase
            switch scope {
            case .privateDB: database = container.privateCloudDatabase
            case .sharedDB: database = container.sharedCloudDatabase
            case .publicDB: database = container.publicCloudDatabase
            }
            do {
                _ = try await database.deleteSubscription(withID: scope.rawValue)
            } catch let error as CKError where error.code == .unknownItem {
                // already gone
            } catch {
                throw SubscriptionError.underlying(error.localizedDescription)
            }
            mark(scope, installed: false)
        }
    }

    public func isInstalled(_ scope: Scope) -> Bool {
        installedScopes().contains(scope)
    }

    // MARK: - Internals

    /// Public DB'de yeni MatchState kaydı oluşturulunca silent push tetiklesin.
    /// CKDatabaseSubscription public DB'yi desteklemediğinden CKQuerySubscription kullanılıyor.
    private func registerPublicMatchState() async throws {
        let subscription = CKQuerySubscription(
            recordType: "MatchState",
            predicate: NSPredicate(value: true),
            subscriptionID: Scope.publicDB.rawValue,
            options: [.firesOnRecordCreation]
        )
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        do {
            _ = try await container.publicCloudDatabase.modifySubscriptions(
                saving: [subscription],
                deleting: []
            )
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Already exists — treat as success
        } catch {
            throw SubscriptionError.underlying(error.localizedDescription)
        }
    }

    private func register(scope: Scope, in database: CKDatabase) async throws {
        let subscription = CKDatabaseSubscription(subscriptionID: scope.rawValue)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true   // silent push
        subscription.notificationInfo = info

        do {
            _ = try await database.modifySubscriptions(
                saving: [subscription],
                deleting: []
            )
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Already exists — treat as success
        } catch {
            throw SubscriptionError.underlying(error.localizedDescription)
        }
    }

    private func installedScopes() -> Set<Scope> {
        let raw = userDefaults.array(forKey: storageKey) as? [String] ?? []
        return Set(raw.compactMap(Scope.init(rawValue:)))
    }

    private func mark(_ scope: Scope, installed: Bool) {
        var scopes = installedScopes()
        if installed { scopes.insert(scope) } else { scopes.remove(scope) }
        userDefaults.set(scopes.map(\.rawValue), forKey: storageKey)
    }
}
