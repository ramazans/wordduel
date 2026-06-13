import Foundation
#if canImport(Security)
import Security
#endif

/// Apple `appleUserID` → görünen ad eşlemesini kalıcı saklayan depo.
///
/// **Neden gerekli:** Apple `fullName`'i yalnızca İLK onayda gönderir. Kullanıcı
/// uygulamayı silip yeniden kurunca sonraki girişte isim boş gelir; yerel
/// SwiftData ve `UserDefaults` de silindiği için ismi kurtaracak hiçbir kayıt
/// kalmaz. Keychain öğeleri ise uygulama kaldırılınca temizlenmediğinden, ismi
/// burada saklayıp yeniden kurulumda geri yükleyebiliriz. `appleUserID` sabit
/// kaldığından doğru kullanıcıya bağlanır.
public protocol ProfileNameStore: Sendable {
    func displayName(for appleUserID: String) -> String?
    func setDisplayName(_ name: String, for appleUserID: String)
    func removeDisplayName(for appleUserID: String)
}

/// Keychain (`kSecClassGenericPassword`) tabanlı kalıcı `ProfileNameStore`.
/// `kSecAttrAccessibleAfterFirstUnlock`: cihaz ilk açılıştan sonra kilitliyken
/// de okunabilir ve uygulama kaldırılsa bile Keychain'de kalır — reinstall'da
/// ismin kurtarılmasını sağlayan tam da bu kalıcılıktır.
public final class KeychainProfileStore: ProfileNameStore {
    private let service: String

    public init(service: String = "club.kadro.wordduel.profile") {
        self.service = service
    }

    public func displayName(for appleUserID: String) -> String? {
        #if canImport(Security)
        var query = baseQuery(account: appleUserID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let name = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
        #else
        return nil
        #endif
    }

    public func setDisplayName(_ name: String, for appleUserID: String) {
        #if canImport(Security)
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }

        // Idempotent upsert: önce sil, sonra ekle.
        SecItemDelete(baseQuery(account: appleUserID) as CFDictionary)

        var attributes = baseQuery(account: appleUserID)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
        #endif
    }

    public func removeDisplayName(for appleUserID: String) {
        #if canImport(Security)
        SecItemDelete(baseQuery(account: appleUserID) as CFDictionary)
        #endif
    }

    #if canImport(Security)
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
    #endif
}
