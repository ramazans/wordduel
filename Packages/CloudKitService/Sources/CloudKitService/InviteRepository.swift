import Foundation
import CloudKit

/// `MatchInvite` kayıtlarını public DB üzerinde yöneten repo.
/// Kod → shareURL lookup'ı için ana giriş noktası.
public actor InviteRepository {
    public enum InviteError: Error, Sendable, Equatable {
        case codeNotFound
        case codeExpired
        case underlying(String)
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
    public func find(byCode code: String) async throws -> MatchInvite {
        let normalized = MatchCodeGenerator.normalize(code)
        guard MatchCodeGenerator.isValid(normalized) else {
            throw InviteError.codeNotFound
        }

        let predicate = NSPredicate(format: "%K == %@", MatchInvite.Field.code, normalized)
        let query = CKQuery(recordType: MatchInvite.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: MatchInvite.Field.createdAt, ascending: false)]

        let results: [CKRecord]
        do {
            let response = try await database.records(matching: query, resultsLimit: 1)
            results = response.matchResults.compactMap { try? $0.1.get() }
        } catch {
            throw InviteError.underlying(error.localizedDescription)
        }

        guard let record = results.first else {
            throw InviteError.codeNotFound
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
