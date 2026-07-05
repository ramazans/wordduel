import SwiftUI

/// Baş harfli, renkli oyuncu avatarı. `isHighlighted` kazananı altın halka ile vurgular.
public struct AvatarView: View {
    private let name: String
    private let colorIndex: Int
    private let size: CGFloat
    private let isHighlighted: Bool

    public init(
        name: String,
        colorIndex: Int = 0,
        size: CGFloat = 56,
        isHighlighted: Bool = false
    ) {
        self.name = name
        self.colorIndex = colorIndex
        self.size = size
        self.isHighlighted = isHighlighted
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(AvatarPalette.color(for: colorIndex).gradient)
            Text(initial)
                .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(
            // King tarzı kalın çerçeve — yüzey renginde halka.
            Circle().strokeBorder(Color.wdSurface, lineWidth: max(2, size * 0.05))
        )
        .overlay {
            if isHighlighted {
                Circle()
                    .strokeBorder(LinearGradient.wdGoldGradient, lineWidth: 3.5)
                    .padding(-5)
            }
        }
        .shadow(
            color: AvatarPalette.color(for: colorIndex).opacity(0.4),
            radius: size / 8, x: 0, y: size / 14
        )
        .accessibilityHidden(true)
    }

    private var initial: String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}

#Preview {
    HStack(spacing: 24) {
        AvatarView(name: "Ali", colorIndex: 0, size: 72, isHighlighted: true)
        AvatarView(name: "Ayşe", colorIndex: 2, size: 72)
        AvatarView(name: "", colorIndex: 5, size: 44)
    }
    .padding(32)
}
