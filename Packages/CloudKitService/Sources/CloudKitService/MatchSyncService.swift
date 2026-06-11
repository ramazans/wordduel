import Foundation
import CloudKit

/// Maç oluşturma/katılma için CloudKit giriş noktası.
///
/// Mimari: oyun durumu CloudKit **public DB** üzerinden taşınır —
/// `MatchInvite` kod → maç eşlemesi, `MatchState` (bkz.
/// `MatchStateRepository`) append-only durum revizyonları. SwiftData yalnızca
/// yerel kalıcılıktır; CKShare/private-zone paylaşımı kullanılmaz çünkü
/// SwiftData'nın CloudKit aynası paylaşılan zone'ları desteklemez (önceki
/// CKShare tabanlı deneme bu yüzden boş zone paylaşıyordu ve misafir hiçbir
/// zaman maç verisi alamıyordu).
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

    public struct NewMatchProvisioning: Sendable {
        public let code: String
        public let shareURL: URL
        public let hostUserRecordName: String
    }

    public struct AcceptedMatchInfo: Sendable {
        public let code: String
        public let hostUserRecordName: String
    }

    public let containerIdentifier: String
    private let container: CKContainer
    public let account: CloudKitAccount
    public let inviteRepository: InviteRepository
    /// Modül dışından (app katmanı) senkron erişim için nonisolated —
    /// aktör tipler Sendable olduğundan güvenli.
    public nonisolated let stateRepository: MatchStateRepository

    public init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
        let container = CKContainer(identifier: containerIdentifier)
        self.container = container
        self.account = CloudKitAccount(containerIdentifier: containerIdentifier)
        self.inviteRepository = InviteRepository(container: container)
        self.stateRepository = MatchStateRepository(container: container)
    }

    // MARK: - Provision

    /// Yeni bir maç için CloudKit tarafını hazırlar:
    ///   1. Hesap durumu kontrolü
    ///   2. Davet kodu üretimi
    ///   3. Public DB'ye `MatchInvite` yazımı
    ///
    /// SwiftData `Match` kaydı ve ilk `MatchState` revizyonu caller tarafında
    /// (`@MainActor` view model) oluşturulur.
    public func provisionMatch() async throws -> NewMatchProvisioning {
        let availability = await account.availability()
        guard availability.isAvailable else {
            throw SyncError.accountUnavailable
        }

        let code = MatchCodeGenerator.generate()
        // Derin bağlantı placeholder'ı — davet kaydı bir URL alanı bekliyor;
        // oyun verisi taşımaz, yalnızca paylaşım metni için.
        guard let joinURL = URL(string: "wordduel://join/\(code)") else {
            throw SyncError.underlying("join URL oluşturulamadı")
        }

        let userRecordID = try await container.userRecordID()
        let invite = MatchInvite(
            code: code,
            shareURL: joinURL,
            hostUserRecordName: userRecordID.recordName
        )
        try await inviteRepository.write(invite)

        return NewMatchProvisioning(
            code: code,
            shareURL: joinURL,
            hostUserRecordName: userRecordID.recordName
        )
    }

    // MARK: - Accept

    /// Kodu doğrular: public DB'de geçerli bir davet var mı?
    /// Maç durumunun indirilmesi caller tarafında `MatchStateRepository`
    /// üzerinden yapılır.
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

        return AcceptedMatchInfo(
            code: invite.code,
            hostUserRecordName: invite.hostUserRecordName
        )
    }
}
