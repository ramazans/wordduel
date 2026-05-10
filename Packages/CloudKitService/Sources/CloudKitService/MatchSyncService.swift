import Foundation
import CloudKit
import CoreModels

/// CloudKit `private` + `shared` DB için maç senkronizasyonu.
/// CKShare oluşturma/kabul, query subscription, çakışma çözümü.
/// Faz 4 ve Faz 5'te doldurulacak.
public actor MatchSyncService {
    public enum SyncError: Error, Sendable {
        case notSignedIn
        case shareNotFound
        case codeNotFound
        case accountUnavailable
    }

    private let container: CKContainer
    public let account: CloudKitAccount

    public init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.account = CloudKitAccount(containerIdentifier: containerIdentifier)
    }

    // MARK: - Match creation (Faz 4)

    public func createMatch(_ match: Match) async throws -> URL {
        // TODO Faz 4: private DB kayıt + CKShare oluştur, share.url döndür.
        throw SyncError.notSignedIn
    }

    // MARK: - Join by code (Faz 4)

    public func acceptMatch(byCode code: String) async throws -> Match {
        // TODO Faz 4: public lookup record → CKShare URL → accept → Match döndür.
        throw SyncError.codeNotFound
    }

    // MARK: - Subscription (Faz 5)

    public func subscribeToActiveMatches() async throws {
        // TODO Faz 5: CKQuerySubscription her aktif Match için.
    }
}
