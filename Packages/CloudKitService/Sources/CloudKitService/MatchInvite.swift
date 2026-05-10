import Foundation
import CloudKit

/// Public DB'de tutulan davet kaydı. Davet eden host'un yazdığı bu kayıt,
/// 6 haneli kodu CKShare URL'ine bağlar. Davet edilen kullanıcı kodla bu
/// kaydı bulup share'i kabul eder.
///
/// Gizlilik: Public DB'de duruyor ama içeriği yalnızca opaque shareURL ve
/// host kullanıcı id'si — kelime/maç verisi yok. Kayıt TTL ile sınırlı.
public struct MatchInvite: Sendable, Equatable {
    public static let recordType = "MatchInvite"

    public enum Field {
        public static let code = "code"
        public static let shareURL = "shareURL"
        public static let hostUserRecordName = "hostUserRecordName"
        public static let createdAt = "createdAt"
        public static let expiresAt = "expiresAt"
    }

    public let code: String
    public let shareURL: URL
    public let hostUserRecordName: String
    public let createdAt: Date
    public let expiresAt: Date

    public init(
        code: String,
        shareURL: URL,
        hostUserRecordName: String,
        createdAt: Date = .now,
        ttl: TimeInterval = 7 * 24 * 60 * 60 // 7 gün
    ) {
        self.code = code
        self.shareURL = shareURL
        self.hostUserRecordName = hostUserRecordName
        self.createdAt = createdAt
        self.expiresAt = createdAt.addingTimeInterval(ttl)
    }

    public init(record: CKRecord) throws {
        guard
            let code = record[Field.code] as? String,
            let urlString = record[Field.shareURL] as? String,
            let url = URL(string: urlString),
            let host = record[Field.hostUserRecordName] as? String,
            let created = record[Field.createdAt] as? Date,
            let expires = record[Field.expiresAt] as? Date
        else {
            throw RecordError.malformed
        }
        self.code = code
        self.shareURL = url
        self.hostUserRecordName = host
        self.createdAt = created
        self.expiresAt = expires
    }

    public func asRecord(recordID: CKRecord.ID? = nil) -> CKRecord {
        let id = recordID ?? CKRecord.ID(recordName: "invite-\(code)")
        let record = CKRecord(recordType: Self.recordType, recordID: id)
        record[Field.code] = code as NSString
        record[Field.shareURL] = shareURL.absoluteString as NSString
        record[Field.hostUserRecordName] = hostUserRecordName as NSString
        record[Field.createdAt] = createdAt as NSDate
        record[Field.expiresAt] = expiresAt as NSDate
        return record
    }

    public var isExpired: Bool { expiresAt < .now }

    public enum RecordError: Error, Sendable, Equatable {
        case malformed
    }
}
