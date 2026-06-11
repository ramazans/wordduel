import Foundation
import CloudKit

/// Maç durum revizyonlarını public DB'de saklayan depo.
///
/// Tasarım: append-only. Her revizyon `state-<kod>-<revizyon>` adlı YENİ bir
/// kayıttır; mevcut kayıt asla güncellenmez. Bu sayede:
/// - Public DB'nin "yalnızca oluşturan günceller" kuralına takılmaz
///   (iki oyuncu da kendi mutasyonunu kendi kaydı olarak yazar),
/// - Sorgu indeksi gerekmez (okuma, kayıt adı ile doğrudan fetch),
/// - Aynı revizyonu iki cihaz aynı anda yazarsa ikincisi `revisionConflict`
///   alır ve pull ederek uzlaşır.
public actor MatchStateRepository {
    public enum StateError: Error, Sendable, Equatable {
        case revisionConflict
        case underlying(String)
    }

    public static let recordType = "MatchState"

    private let database: CKDatabase

    public init(container: CKContainer) {
        self.database = container.publicCloudDatabase
    }

    private static func recordID(code: String, revision: Int) -> CKRecord.ID {
        CKRecord.ID(recordName: "state-\(code)-\(revision)")
    }

    /// Yeni revizyon yazar. Aynı revizyon zaten varsa `revisionConflict`.
    public func push(code: String, revision: Int, payload: Data) async throws {
        let record = CKRecord(
            recordType: Self.recordType,
            recordID: Self.recordID(code: code, revision: revision)
        )
        record["code"] = code as NSString
        record["revision"] = revision as NSNumber
        record["payload"] = payload as NSData
        record["createdAt"] = Date() as NSDate

        do {
            _ = try await database.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            throw StateError.revisionConflict
        } catch let error as CKError where error.code == .constraintViolation {
            throw StateError.revisionConflict
        } catch {
            throw StateError.underlying(error.localizedDescription)
        }
    }

    /// Belirli bir revizyonu getirir; yoksa `nil` (zincirin sonu).
    public func fetch(code: String, revision: Int) async throws -> Data? {
        do {
            let record = try await database.record(for: Self.recordID(code: code, revision: revision))
            return record["payload"] as? Data
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw StateError.underlying(error.localizedDescription)
        }
    }
}
