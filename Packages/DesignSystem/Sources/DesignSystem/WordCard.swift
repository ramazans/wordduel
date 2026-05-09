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
        VStack(spacing: 12) {
            if isRepeat {
                Label("Tekrar", systemImage: "arrow.clockwise")
                    .font(.wdCaption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.orange.opacity(0.15), in: Capsule())
            }

            Text(word)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)

            if let hint, !hint.isEmpty {
                Text(hint)
                    .font(.wdCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.wdSeparator, lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    VStack(spacing: 16) {
        WordCard(word: "ephemeral", hint: "B2")
        WordCard(word: "diligent", isRepeat: true)
    }
    .padding()
}
