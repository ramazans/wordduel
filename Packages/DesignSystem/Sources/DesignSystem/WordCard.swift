import SwiftUI

public struct WordCard: View {
    private let word: String
    private let hint: String?
    private let isRepeat: Bool

    public init(word: String, hint: String? = nil, isRepeat: Bool = false) {
        self.word = word
        self.hint = hint
        self.isRepeat = isRepeat
    }

    public var body: some View {
        VStack(spacing: WDSpacing.md) {
            if isRepeat {
                Label("Tekrar", systemImage: "arrow.clockwise")
                    .font(.wdLabel)
                    .foregroundStyle(Color.wdWarning)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.wdWarning.opacity(0.15), in: Capsule())
                    .accessibilityLabel("Tekrar sorulan kelime")
            }

            Text(word)
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.wdInk)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .id(word)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.85).combined(with: .opacity),
                    removal: .opacity
                ))

            if let hint, !hint.isEmpty {
                Label(hint.uppercased(), systemImage: "star.fill")
                    .font(.wdLabel)
                    .foregroundStyle(Color.wdGoldEdge)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.wdGold.opacity(0.18), in: Capsule())
            }
        }
        .padding(WDSpacing.xl)
        .frame(maxWidth: .infinity)
        .wdCard(padding: 0, cornerRadius: WDRadius.xl)
        .animation(.spring(duration: 0.5), value: word)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityLabel(accessibilityLabelText)
    }

    private var accessibilityLabelText: String {
        var parts: [String] = []
        if isRepeat { parts.append("Tekrar sorulan kelime") }
        parts.append("Kelime: \(word)")
        if let hint, !hint.isEmpty { parts.append("Seviye: \(hint)") }
        return parts.joined(separator: ", ")
    }
}

#Preview {
    VStack(spacing: 16) {
        WordCard(word: "ephemeral", hint: "B2")
        WordCard(word: "diligent", isRepeat: true)
    }
    .padding()
}
