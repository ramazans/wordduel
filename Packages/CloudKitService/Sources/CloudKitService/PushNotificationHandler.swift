import Foundation
import CloudKit

/// Gelen `userInfo` payload'unu CKNotification'a ayrıştırır ve uygulamaya
/// ne tür bir güncelleme olduğunu bildirir. SwiftData + CloudKit otomatik sync
/// kullanıldığı için fetch'i kendisi yapmaz — yalnızca yönlendirir.
public enum PushNotificationHandler {
    public enum Outcome: Sendable, Equatable {
        case databaseChanged(scope: CKDatabase.Scope)
        case ignored
    }

    public static func handle(userInfo: [AnyHashable: Any]) -> Outcome {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return .ignored
        }
        if let dbNotification = notification as? CKDatabaseNotification {
            return .databaseChanged(scope: dbNotification.databaseScope)
        }
        // CKQuerySubscription (public DB için kullanılır) CKQueryNotification üretir.
        if let queryNotification = notification as? CKQueryNotification {
            return .databaseChanged(scope: queryNotification.databaseScope)
        }
        return .ignored
    }
}
