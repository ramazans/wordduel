import Foundation
import CloudKit

/// CloudKit hesap durumu kontrolü için ince wrapper.
/// `CKAccountStatus` yanı sıra kullanıcıya uygun mesajı üretir.
public struct CloudKitAccount: Sendable {
    public let containerIdentifier: String

    public init(containerIdentifier: String) {
        self.containerIdentifier = containerIdentifier
    }

    public func status() async throws -> CKAccountStatus {
        try await CKContainer(identifier: containerIdentifier).accountStatus()
    }

    public func userRecordID() async throws -> CKRecord.ID {
        try await CKContainer(identifier: containerIdentifier).userRecordID()
    }

    public enum Availability: Equatable, Sendable {
        case available
        case noAccount
        case restricted
        case couldNotDetermine
        case temporarilyUnavailable

        public var isAvailable: Bool { self == .available }

        public var userMessage: String {
            switch self {
            case .available:
                return ""
            case .noAccount:
                return "iCloud hesabına giriş yapmalısın. Ayarlar > [Adın] altından giriş yap."
            case .restricted:
                return "Cihazda iCloud kısıtlanmış. Yöneticinle iletişime geç."
            case .couldNotDetermine:
                return "iCloud durumu doğrulanamadı. İnternet bağlantını kontrol et."
            case .temporarilyUnavailable:
                return "iCloud şu anda kullanılamıyor. Lütfen daha sonra tekrar dene."
            }
        }
    }

    public func availability() async -> Availability {
        do {
            let status = try await self.status()
            return Self.map(status)
        } catch {
            return .couldNotDetermine
        }
    }

    static func map(_ status: CKAccountStatus) -> Availability {
        switch status {
        case .available: return .available
        case .noAccount: return .noAccount
        case .restricted: return .restricted
        case .couldNotDetermine: return .couldNotDetermine
        case .temporarilyUnavailable: return .temporarilyUnavailable
        @unknown default: return .couldNotDetermine
        }
    }
}
