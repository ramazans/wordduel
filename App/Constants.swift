import Foundation

public enum AppConstants {
    /// CloudKit container identifier.
    /// Faz 2 — Mac'te Xcode'da CloudKit capability eklenirken bu identifier'a göre
    /// container oluşturulur. Format: `iCloud.<bundleID>` veya manuel olarak
    /// `iCloud.com.<team>.wordduel`.
    public static let cloudKitContainerID = "iCloud.club.kadro.wordduel"

    public static let appleUserIDStorageKey = "wordduel.appleUserID"
}
