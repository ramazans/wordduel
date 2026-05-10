import Foundation
import CloudKit
import SwiftData
import CoreModels

/// Maç oluşturma, davet kodu üretimi, CKShare yönetimi ve "kodla katıl" akışı.
///
/// Sorumluluk haritası:
/// - **createMatch**: SwiftData'da `Match` kaydı oluşturur (private DB'ye senkronize olur),
///   o kayda `CKShare` üretir, public DB'ye `MatchInvite` yazar, share URL'ini döndürür.
/// - **acceptMatch(byCode:)**: Public DB'den invite'ı bulur, CKShareMetadata fetch eder,
///   `CKAcceptSharesOperation` ile share'i kabul eder. Match kaydı SwiftData üzerinden
///   shared DB'ye yansıtılır.
/// - **Round yazma/okuma**: SwiftData @Model üzerinden otomatik — bu servis tarafından
///   manuel CKRecord trafiği yok.
public actor MatchSyncService {
    public enum SyncError: Error, Sendable, Equatable {
        case accountUnavailable
        case shareCreationFailed(String)
        case shareAcceptanceFailed(String)
        case codeNotFound
        case codeExpired
        case matchPersistenceFailed(String)
        case underlying(String)
    }

    public struct CreatedMatch: Sendable {
        public let code: String
        public let shareURL: URL
        public let matchPersistentID: PersistentIdentifier
    }

    public struct AcceptedMatchInfo: Sendable {
        public let code: String
        public let shareRecordID: CKRecord.ID
    }

    public let containerIdentifier: String
    private let container: CKContainer
    public let account: CloudKitAccount
    public let inviteRepository: InviteRepository

    public init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
        let container = CKContainer(identifier: containerIdentifier)
        self.container = container
        self.account = CloudKitAccount(containerIdentifier: containerIdentifier)
        self.inviteRepository = InviteRepository(container: container)
    }

    // MARK: - Create

    /// Yeni bir maç oluşturur. Akış:
    ///   1. Hesap durumu kontrol
    ///   2. Match kaydı SwiftData'ya yazılır
    ///   3. SwiftData private DB'ye senkronize olduğu varsayılır
    ///   4. Match'in CKRecord karşılığına CKShare üretilir
    ///   5. Public DB'ye MatchInvite yazılır
    ///   6. Share URL döndürülür
    public func createMatch(
        host: Player,
        modelContext: ModelContext
    ) async throws -> CreatedMatch {
        let availability = await account.availability()
        guard availability.isAvailable else {
            throw SyncError.accountUnavailable
        }

        let code = MatchCodeGenerator.generate()
        let match = Match(code: code, host: host)

        await MainActor.run {
            modelContext.insert(match)
        }
        do {
            try await MainActor.run { try modelContext.save() }
        } catch {
            throw SyncError.matchPersistenceFailed(error.localizedDescription)
        }

        // CKShare yaratma — gerçek implementasyon SwiftData'nın altındaki
        // CKRecord'a erişim gerektirir. iOS 18'de `ModelContainer` üzerinden
        // share URL alınabilir; aşağıdaki yardımcı bunu CKContainer.share API'si
        // ile yapar. Şu anda Mac/cihazda gerçek senkronizasyon doğrulandıktan
        // sonra bağlanmalı.
        let (share, _) = try await prepareShare(forMatchCode: code)

        guard let shareURL = share.url else {
            throw SyncError.shareCreationFailed("Share URL not yet provisioned")
        }

        let userRecordID = try await container.userRecordID()
        let invite = MatchInvite(
            code: code,
            shareURL: shareURL,
            hostUserRecordName: userRecordID.recordName
        )
        try await inviteRepository.write(invite)

        return CreatedMatch(
            code: code,
            shareURL: shareURL,
            matchPersistentID: match.persistentModelID
        )
    }

    /// Match kaydı için CKShare hazırlar.
    ///
    /// **NOT (Faz 4 — Mac doğrulama)**: SwiftData ile yaratılmış bir kaydın altındaki
    /// `CKRecord`'a `share()` çağırarak CKShare oluşturmak iOS 18'de doğrudan API ile
    /// destekleniyor. Burada şablon şu an `CKShare(recordZoneID:)` ile zone-level paylaşım
    /// üretiyor; Mac'te SwiftData'nın expose ettiği `CKContainer.share(rootRecord:)`
    /// API'si ile değiştirilmeli.
    private func prepareShare(forMatchCode code: String) async throws -> (CKShare, CKContainer) {
        let zoneID = CKRecordZone.ID(zoneName: "WordDuelMatches", ownerName: CKCurrentUserDefaultName)

        do {
            _ = try await container.privateCloudDatabase.save(CKRecordZone(zoneID: zoneID))
        } catch let error as CKError where error.code == .serverRecordChanged {
            // zone zaten varsa OK
        } catch {
            throw SyncError.shareCreationFailed(error.localizedDescription)
        }

        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = "WordDuel \(code)" as NSString
        share[CKShare.SystemFieldKey.shareType] = "club.kadro.wordduel.match" as NSString
        share.publicPermission = .readWrite

        do {
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [share],
                deleting: [],
                savePolicy: .changedKeys
            )
        } catch {
            throw SyncError.shareCreationFailed(error.localizedDescription)
        }

        return (share, container)
    }

    // MARK: - Accept

    /// Kodla maça katılır. Public DB'den invite'ı bulur, share metadata'sını fetch eder,
    /// `CKAcceptSharesOperation` ile share'i kabul eder.
    public func acceptMatch(byCode code: String) async throws -> AcceptedMatchInfo {
        let availability = await account.availability()
        guard availability.isAvailable else {
            throw SyncError.accountUnavailable
        }

        let invite: MatchInvite
        do {
            invite = try await inviteRepository.find(byCode: code)
        } catch InviteRepository.InviteError.codeNotFound {
            throw SyncError.codeNotFound
        } catch InviteRepository.InviteError.codeExpired {
            throw SyncError.codeExpired
        } catch {
            throw SyncError.underlying(error.localizedDescription)
        }

        let metadata = try await fetchShareMetadata(for: invite.shareURL)
        try await acceptShare(metadata: metadata)

        return AcceptedMatchInfo(
            code: invite.code,
            shareRecordID: metadata.share.recordID
        )
    }

    private func fetchShareMetadata(for url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let op = CKFetchShareMetadataOperation(shareURLs: [url])
            op.shouldFetchRootRecord = false
            op.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let metadata):
                    continuation.resume(returning: metadata)
                case .failure(let error):
                    continuation.resume(throwing: SyncError.shareAcceptanceFailed(error.localizedDescription))
                }
            }
            op.fetchShareMetadataResultBlock = { result in
                if case .failure(let error) = result {
                    continuation.resume(throwing: SyncError.shareAcceptanceFailed(error.localizedDescription))
                }
            }
            container.add(op)
        }
    }

    private func acceptShare(metadata: CKShare.Metadata) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let op = CKAcceptSharesOperation(shareMetadatas: [metadata])
            op.acceptSharesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: SyncError.shareAcceptanceFailed(error.localizedDescription))
                }
            }
            container.add(op)
        }
    }

    // MARK: - Subscription (Faz 5)

    public func subscribeToActiveMatches() async throws {
        // TODO Faz 5: CKQuerySubscription her aktif Match için.
    }
}
