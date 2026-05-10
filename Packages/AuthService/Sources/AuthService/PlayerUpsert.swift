import Foundation
import SwiftData
import CoreModels

public enum PlayerUpsert {
    /// `appleUserID` benzersiz olduğu için bu id ile mevcut bir Player varsa güncellenir;
    /// yoksa yeni Player oluşturulup context'e insert edilir.
    /// - Note: Apple yalnızca ilk girişte `fullName` döndürür, sonraki çağrılarda boş gelir.
    ///   Bu yüzden `displayName` yalnızca boş değilse ve mevcut kayıt boşsa güncellenir.
    @discardableResult
    public static func upsert(
        appleUserID: String,
        displayName: String,
        in context: ModelContext
    ) throws -> Player {
        var descriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.appleUserID == appleUserID }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            if !displayName.isEmpty, existing.displayName.isEmpty {
                existing.displayName = displayName
            }
            return existing
        }

        let resolvedName = displayName.isEmpty ? defaultDisplayName(for: appleUserID) : displayName
        let new = Player(
            appleUserID: appleUserID,
            displayName: resolvedName,
            avatarColor: stableAvatarIndex(for: appleUserID)
        )
        context.insert(new)
        try context.save()
        return new
    }

    public static func delete(appleUserID: String, in context: ModelContext) throws {
        var descriptor = FetchDescriptor<Player>(
            predicate: #Predicate { $0.appleUserID == appleUserID }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }

    // MARK: - Helpers

    static func defaultDisplayName(for appleUserID: String) -> String {
        // Apple kullanıcı id'si "001234.abcdef..." formatında. Son 4 karakteri kullanıcı dostu suffix.
        let suffix = String(appleUserID.suffix(4))
        return "Player-\(suffix)"
    }

    static func stableAvatarIndex(for appleUserID: String) -> Int {
        // Deterministik renk seçimi — aynı kullanıcı her cihazda aynı renk.
        var hash = 5381
        for byte in appleUserID.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return abs(hash) % 8
    }
}
