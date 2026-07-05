import SwiftUI

/// 4'lü ritimde boşluk ölçeği.
public enum WDSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

/// Köşe yarıçapı ölçeği — her zaman `.continuous` stil ile kullanılır.
/// King Style: cömert, bonbon gibi yuvarlak köşeler.
public enum WDRadius {
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 18
    public static let lg: CGFloat = 24
    public static let xl: CGFloat = 32
}

/// 3B kenar (bevel) yükseklikleri — King Style'ın "basılabilir şeker" hissi.
public enum WDBevel {
    /// Kart ve kutuların alt kenarı.
    public static let card: CGFloat = 3
    /// Butonların alt kenarı; basılınca 1'e iner.
    public static let button: CGFloat = 4
}

public extension View {
    /// Tam ekran zemini: lavanta gökyüzü gradyanı (safe area'yı da doldurur).
    func wdScreenBackground() -> some View {
        background(LinearGradient.wdScreenGradient.ignoresSafeArea())
    }

    /// Kart yüzeyi: şeker paneli — kalın alt kenar (bevel), ince kontur,
    /// mor tonlu yumuşak gölge, geniş köşe.
    func wdCard(
        padding: CGFloat = WDSpacing.md,
        cornerRadius: CGFloat = WDRadius.lg
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .padding(padding)
            .background(
                // Sıfır yarıçaplı sert gölge = düz 3B alt kenar.
                shape.fill(Color.wdSurface)
                    .shadow(color: .wdSurfaceEdge, radius: 0, x: 0, y: WDBevel.card)
            )
            .overlay(
                shape.strokeBorder(Color.wdSeparator.opacity(0.5), lineWidth: 1)
            )
            .shadow(color: Color.wdShadow.opacity(0.10), radius: 14, x: 0, y: 8)
    }
}

/// Basılınca hafifçe küçülen stil — kart ve satır butonları için.
public struct WDPressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// King Style 3B buton: parlak dolgu + koyu alt kenar (bevel); basılınca
/// buton kenarına "oturur". `Button` dışında `ShareLink` gibi buton-tabanlı
/// kontrollere de uygulanabilir.
public struct WDProminentButtonStyle: ButtonStyle {
    public enum Variant {
        case primary
        case secondary
        case destructive
        /// Onay / "oyna" aksiyonları — elma şekeri yeşili.
        case success
    }

    private let variant: Variant
    @Environment(\.isEnabled) private var isEnabled

    public init(_ variant: Variant = .primary) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)

        return configuration.label
            .font(.wdHeadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(foreground)
            .background(
                shape.fill(background)
                    .overlay(
                        // Şeker parlaması: üstte beyaz ışıltı.
                        shape.fill(
                            LinearGradient(
                                colors: [.white.opacity(glossOpacity), .white.opacity(0)],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                    )
                    // Sıfır yarıçaplı sert gölge = düz 3B alt kenar.
                    .shadow(
                        color: edge,
                        radius: 0, x: 0,
                        y: pressed ? 1 : WDBevel.button
                    )
            )
            .shadow(
                color: shadowColor.opacity(isEnabled && !pressed ? 0.35 : 0),
                radius: 12, x: 0, y: 8
            )
            .offset(y: pressed ? WDBevel.button - 1 : 0)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(.spring(duration: 0.2), value: pressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive, .success: return .white
        case .secondary: return .wdInk
        }
    }

    private var background: AnyShapeStyle {
        switch variant {
        case .primary: return AnyShapeStyle(LinearGradient.wdAccentGradient)
        case .secondary: return AnyShapeStyle(Color.wdSurface)
        case .destructive: return AnyShapeStyle(Color.wdDanger)
        case .success: return AnyShapeStyle(LinearGradient.wdSuccessGradient)
        }
    }

    private var edge: Color {
        switch variant {
        case .primary: return .wdAccentEdge
        case .secondary: return .wdSurfaceEdge
        case .destructive: return .wdDangerEdge
        case .success: return .wdSuccessEdge
        }
    }

    private var glossOpacity: Double {
        switch variant {
        case .secondary: return 0
        case .primary, .destructive, .success: return 0.28
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .primary: return .wdAccent
        case .secondary: return .wdShadow.opacity(0.3)
        case .destructive: return .wdDanger
        case .success: return .wdSuccess
        }
    }
}
