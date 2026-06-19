import Foundation
import CloudKit

/// `MatchInvite` kayıtlarını public DB üzerinde yöneten repo.
/// Kod → shareURL lookup'ı için ana giriş noktası.
public actor InviteRepository {
    public enum InviteError: Error, Sendable, Equatable, LocalizedError {
        case codeNotFound
        case codeExpired
        case underlying(String)

        // Gerçek hata mesajı yüzeye çıksın diye; aksi halde
        // `localizedDescription` "İşlem tamamlanamadı (CloudKitService...)"
        // gibi anlamsız bir metne düşüyor ve asıl neden kayboluyor.
        public var errorDescription: String? {
            switch self {
            case .codeNotFound: return "Kod bulunamadı."
            case .codeExpired: return "Kodun süresi dolmuş."
            case .underlying(let detail): return detail
            }
        }
    }

    private let database: CKDatabase

    public init(container: CKContainer) {
        self.database = container.publicCloudDatabase
    }

    /// Yeni invite yazar. Aynı kod varsa overwrite eder (host yeniden paylaşırsa).
    public func write(_ invite: MatchInvite) async throws {
        let record = invite.asRecord()
        do {
            _ = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .changedKeys
            )
        } catch {
            throw InviteError.underlying(error.localizedDescription)
        }
    }

    /// Kodla davet kaydını bulur. Süresi dolmuşsa `.codeExpired` fırlatır.
    ///
    /// Davet kaydı deterministik bir record ID ("invite-<kod>") ile yazıldığı
    /// için (bkz. `MatchInvite.asRecord` ve `delete`), kaydı sorgu yerine
    /// doğrudan ID ile çekiyoruz. `CKQuery` yaklaşımı public DB şemasında
    /// `code` alanının "Queryable", `createdAt` alanının "Sortable" olarak
    /// indekslenmesini gerektirir; bu indeksler CloudKit Dashboard'da tanımlı
    /// değilse katılma, maskelenen bir CloudKit hatasıyla başarısız olur.
    /// ID ile çekim indeks gerektirmez, ayrıca daha hızlı ve ucuzdur.
    public func find(byCode code: String) async throws -> MatchInvite {
        let normalized = MatchCodeGenerator.normalize(code)
        guard MatchCodeGenerator.isValid(normalized) else {
            throw InviteError.codeNotFound
        }

        let recordID = CKRecord.ID(recordName: "invite-\(normalized)")
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            throw InviteError.codeNotFound
        } catch {
            throw InviteError.underlying(error.localizedDescription)
        }

        let invite = try MatchInvite(record: record)
        if invite.isExpired {
            throw InviteError.codeExpired
        }
        return invite
    }

    public func delete(code: String) async throws {
        let normalized = MatchCodeGenerator.normalize(code)
        let recordID = CKRecord.ID(recordName: "invite-\(normalized)")
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch {
            throw InviteError.underlying(error.localizedDescription)
        }
    }
}
