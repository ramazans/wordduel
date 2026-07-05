import SwiftUI
import UIKit

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    /// Açık/karanlık moda duyarlı renk.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

// MARK: - King Style paleti
// Şeker oyunu estetiği: doygun bonbon renkleri, mor-lavanta gökyüzü zemini,
// her ana rengin butonlarda 3B kenar (bevel) için koyu "edge" karşılığı var.

public extension Color {
    // MARK: Marka

    /// Ana marka rengi — bonbon pembesi.
    static let wdAccent = Color(light: 0xFF2D78, dark: 0xFF4D8F)
    /// Gradient'in koyu ucu.
    static let wdAccentDeep = Color(light: 0xE0146C, dark: 0xE0146C)
    /// Buton alt kenarı (3B bevel) için koyu ton.
    static let wdAccentEdge = Color(light: 0xB40E57, dark: 0x9E0C4C)

    // MARK: Zemin & yüzey

    /// Düz zemin — lavanta. Tam ekranlarda `wdScreenBackground()` gradyanı tercih edilir.
    static let wdBackground = Color(light: 0xF4EFFF, dark: 0x1A1133)
    /// Ekran gradyanının üst (açık) ucu.
    static let wdBackgroundTop = Color(light: 0xF7F3FF, dark: 0x150C2E)
    /// Ekran gradyanının alt (doygun) ucu.
    static let wdBackgroundBottom = Color(light: 0xE7DBFF, dark: 0x2A1B4E)
    /// Kart yüzeyi: açık modda beyaz, karanlıkta yükseltilmiş mor.
    static let wdSurface = Color(light: 0xFFFFFF, dark: 0x271C4D)
    /// İkincil yüzey: girdi alanları, çipler, pasif kutular.
    static let wdSurfaceSecondary = Color(light: 0xF1EAFC, dark: 0x352659)
    /// Kart ve ikincil butonların alt kenarı (3B bevel).
    static let wdSurfaceEdge = Color(light: 0xDCCFF2, dark: 0x140B2B)
    static let wdSecondaryBackground = Color(.secondarySystemBackground)
    static let wdSeparator = Color(light: 0xE0D5F2, dark: 0x453362)
    /// Yumuşak ortam gölgesi — mor tonlu.
    static let wdShadow = Color(light: 0x53357E, dark: 0x000000)

    // MARK: Metin

    static let wdInk = Color(light: 0x3D2E5C, dark: 0xF6F1FF)
    static let wdInkSecondary = Color(light: 0x7D6F99, dark: 0xB3A6D6)

    // MARK: Anlamsal

    static let wdSuccess = Color(light: 0x21A94E, dark: 0x3ED46E)
    static let wdSuccessEdge = Color(light: 0x177A38, dark: 0x14813A)
    static let wdWarning = Color(light: 0xF08A00, dark: 0xFFA938)
    static let wdDanger = Color(light: 0xE03131, dark: 0xFF5D52)
    static let wdDangerEdge = Color(light: 0xA82424, dark: 0xB03030)
    static let wdGold = Color(light: 0xF5A800, dark: 0xFFC400)
    static let wdGoldEdge = Color(light: 0xC07C00, dark: 0xB98A00)

    static let wdTimerNormal = Color.wdInk
    static let wdTimerCritical = Color.wdDanger
}

public extension LinearGradient {
    /// Ana CTA gradient'i — bonbon pembesi, üstü aydınlık (şeker parlaması).
    static let wdAccentGradient = LinearGradient(
        colors: [
            Color(uiColor: UIColor(hex: 0xFF5C9D)),
            Color(uiColor: UIColor(hex: 0xFF2D78)),
            Color(uiColor: UIColor(hex: 0xE0146C))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Kupa ve kutlama vurguları için altın gradient.
    static let wdGoldGradient = LinearGradient(
        colors: [
            Color(uiColor: UIColor(hex: 0xFFD54A)),
            Color(uiColor: UIColor(hex: 0xFFAB00))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Onay / "oyna" aksiyonları için elma şekeri yeşili.
    static let wdSuccessGradient = LinearGradient(
        colors: [
            Color(uiColor: UIColor(hex: 0x54D678)),
            Color(uiColor: UIColor(hex: 0x21A94E))
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Tam ekran zemini — lavanta gökyüzü. Açık/karanlık moda duyarlıdır.
    static let wdScreenGradient = LinearGradient(
        colors: [Color.wdBackgroundTop, Color.wdBackgroundBottom],
        startPoint: .top,
        endPoint: .bottom
    )
}

public enum AvatarPalette {
    /// Bonbon avatar renkleri: yaban mersini, üzüm, sakız pembesi, mandalina,
    /// limon, elma şekeri, nane, lavanta.
    public static let colors: [Color] = [
        Color(uiColor: UIColor(hex: 0x38B6FF)),
        Color(uiColor: UIColor(hex: 0x9C5BFF)),
        Color(uiColor: UIColor(hex: 0xFF5CA8)),
        Color(uiColor: UIColor(hex: 0xFF9F1C)),
        Color(uiColor: UIColor(hex: 0xF2C200)),
        Color(uiColor: UIColor(hex: 0x3FCB63)),
        Color(uiColor: UIColor(hex: 0x2FD6C3)),
        Color(uiColor: UIColor(hex: 0x6C6CFF))
    ]

    public static func color(for index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}
