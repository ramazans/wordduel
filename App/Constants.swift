import Foundation

public enum AppConstants {
    /// CloudKit container identifier.
    /// Xcode'da Signing & Capabilities → iCloud → CloudKit checkbox + Containers
    /// listesine bu ID eklenmeli, böylece Apple Developer Portal'da kaydolur.
    public static let cloudKitContainerID = "iCloud.club.kadro.wordduel"

    /// SwiftData'nın CloudKit aynasını (private DB yedekleme) aç/kapat.
    /// MAÇ SENKRONU BU BAYRAKTAN BAĞIMSIZDIR: oyun durumu public DB'deki
    /// `MatchState` revizyon zinciri üzerinden taşınır (MatchCloudSync).
    /// Bu bayrak yalnızca kişisel verinin iCloud'a aynalanmasını kontrol
    /// eder; kapalıyken de iki cihaz arası oyun çalışır.
    public static let cloudKitEnabled = false

    public static let appleUserIDStorageKey = "wordduel.appleUserID"
}
