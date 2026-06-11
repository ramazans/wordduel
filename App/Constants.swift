import Foundation

public enum AppConstants {
    /// CloudKit container identifier.
    /// Xcode'da Signing & Capabilities → iCloud → CloudKit checkbox + Containers
    /// listesine bu ID eklenmeli, böylece Apple Developer Portal'da kaydolur.
    public static let cloudKitContainerID = "iCloud.club.kadro.wordduel"

    /// CloudKit sync'i aç/kapat.
    /// Container Apple Developer'da kaydolmadıysa `false` bırak — "Bad Container"
    /// log spam'ini önler ve uygulama yine local SwiftData ile çalışır.
    /// Container kaydolunca `true` yap, gerçek sync devreye girer.
    public static let cloudKitEnabled = false

    public static let appleUserIDStorageKey = "wordduel.appleUserID"
}
