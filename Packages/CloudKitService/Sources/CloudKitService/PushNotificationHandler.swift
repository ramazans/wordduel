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
        guard notification.notificationType == .database else {
            return .ignored
        }
        let scope: CKDatabase.Scope
        switch notification.containerIdentifier {
        default:
            scope = (notification as? CKDatabaseNotification)?.databaseScope ?? .private
        }
        return .databaseChanged(scope: scope)
    }
}
