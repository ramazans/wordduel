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

public extension Color {
    // MARK: Marka

    /// Ana marka rengi — sıcak mercan.
    static let wdAccent = Color(light: 0xFF385C, dark: 0xFF5A75)
    /// Gradient'in koyu ucu.
    static let wdAccentDeep = Color(light: 0xD70466, dark: 0xE61E4D)

    // MARK: Zemin & yüzey

    static let wdBackground = Color(.systemBackground)
    /// Kart yüzeyi: açık modda beyaz, karanlıkta yükseltilmiş gri.
    static let wdSurface = Color(light: 0xFFFFFF, dark: 0x1C1C1E)
    /// İkincil yüzey: girdi alanları, çipler, pasif kutular.
    static let wdSurfaceSecondary = Color(light: 0xF7F7F7, dark: 0x2C2C2E)
    static let wdSecondaryBackground = Color(.secondarySystemBackground)
    static let wdSeparator = Color(.separator)

    // MARK: Metin

    static let wdInk = Color(light: 0x222222, dark: 0xF2F2F7)
    static let wdInkSecondary = Color(light: 0x6E6E73, dark: 0x9E9EA5)

    // MARK: Anlamsal

    static let wdSuccess = Color(light: 0x1F8A4C, dark: 0x34C77B)
    static let wdWarning = Color(light: 0xE07912, dark: 0xFFA938)
    static let wdDanger = Color(light: 0xC13515, dark: 0xFF6B4A)
    static let wdGold = Color(light: 0xDBA800, dark: 0xFFD60A)

    static let wdTimerNormal = Color.wdInk
    static let wdTimerCritical = Color.wdDanger
}

public extension LinearGradient {
    /// Ana CTA gradient'i (mercan → koyu pembe).
    static let wdAccentGradient = LinearGradient(
        colors: [
            Color(uiColor: UIColor(hex: 0xFF385C)),
            Color(uiColor: UIColor(hex: 0xE61E4D)),
            Color(uiColor: UIColor(hex: 0xD70466))
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Kupa ve kutlama vurguları için altın gradient.
    static let wdGoldGradient = LinearGradient(
        colors: [
            Color(uiColor: UIColor(hex: 0xFFD60A)),
            Color(uiColor: UIColor(hex: 0xE8A100))
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

public enum AvatarPalette {
    public static let colors: [Color] = [
        .blue, .purple, .pink, .orange, .yellow, .green, .teal, .indigo
    ]

    public static func color(for index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }
}
