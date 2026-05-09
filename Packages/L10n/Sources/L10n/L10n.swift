import Foundation

/// Lokalizasyon helper'ları. App, `Localizable.xcstrings` üzerinden Apple
/// String Catalog kullanır; bu paket runtime dil seçimi ve fallback için.
public enum L10n {
    public enum Language: String, CaseIterable, Sendable {
        case system
        case turkish = "tr"
        case english = "en"

        public var displayName: String {
            switch self {
            case .system: return "Sistem"
            case .turkish: return "Türkçe"
            case .english: return "English"
            }
        }
    }

    /// Kullanıcının seçtiği dile göre `Locale` üretir.
    public static func locale(for language: Language) -> Locale? {
        switch language {
        case .system: return nil
        case .turkish: return Locale(identifier: "tr_TR")
        case .english: return Locale(identifier: "en_US")
        }
    }
}
