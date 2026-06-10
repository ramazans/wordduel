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
public enum WDRadius {
    public static let sm: CGFloat = 10
    public static let md: CGFloat = 14
    public static let lg: CGFloat = 20
    public static let xl: CGFloat = 28
}

public extension View {
    /// Kart yüzeyi: yumuşak gölge, ince kontur, geniş köşe.
    func wdCard(
        padding: CGFloat = WDSpacing.md,
        cornerRadius: CGFloat = WDRadius.lg
    ) -> some View {
        self
            .padding(padding)
            .background(
                Color.wdSurface,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.wdSeparator.opacity(0.4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 4)
    }
}

/// Basılınca hafifçe küçülen stil — kart ve satır butonları için.
public struct WDPressableButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Dolgulu, belirgin buton stili. `Button` dışında `ShareLink` gibi
/// buton-tabanlı kontrollere de uygulanabilir.
public struct WDProminentButtonStyle: ButtonStyle {
    public enum Variant {
        case primary
        case secondary
        case destructive
    }

    private let variant: Variant
    @Environment(\.isEnabled) private var isEnabled

    public init(_ variant: Variant = .primary) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wdHeadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(foreground)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
            )
            .shadow(
                color: shadowColor.opacity(isEnabled ? 0.3 : 0),
                radius: 10, x: 0, y: 5
            )
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive: return .white
        case .secondary: return .wdInk
        }
    }

    private var background: AnyShapeStyle {
        switch variant {
        case .primary: return AnyShapeStyle(LinearGradient.wdAccentGradient)
        case .secondary: return AnyShapeStyle(Color.wdSurfaceSecondary)
        case .destructive: return AnyShapeStyle(Color.wdDanger)
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .primary: return .wdAccent
        case .secondary: return .clear
        case .destructive: return .wdDanger
        }
    }
}
