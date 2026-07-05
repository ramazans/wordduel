import SwiftUI
import DesignSystem

struct ReviewAnswerView: View {
    let word: String
    let expectedAnswer: String
    let givenAnswer: String
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: WDSpacing.lg) {
            VStack(spacing: WDSpacing.xs) {
                Text("Cevabı Değerlendir")
                    .font(.wdTitle)
                    .foregroundStyle(Color.wdInk)
                Text("Rakibinin cevabı sayılır mı? Karar senin.")
                    .font(.wdSubheadline)
                    .foregroundStyle(Color.wdInkSecondary)
            }

            WordCard(word: word)

            VStack(spacing: 0) {
                answerRow(
                    title: "Beklenen cevap",
                    value: expectedAnswer,
                    systemImage: "checkmark.seal.fill",
                    tint: .wdSuccess
                )
                Divider()
                    .padding(.leading, 52)
                answerRow(
                    title: "Onun cevabı",
                    value: givenAnswer.isEmpty ? "Cevap vermedi" : givenAnswer,
                    systemImage: "person.fill",
                    tint: .wdAccent
                )
            }
            .wdCard(padding: WDSpacing.xs)

            Text("Küçük yazım hatalarını görmezden gelebilirsin — önemli olan anlamı bilmesi.")
                .font(.wdCaption)
                .foregroundStyle(Color.wdInkSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: WDSpacing.sm) {
                Button(action: onReject) {
                    Label("Yanlış", systemImage: "xmark")
                        .font(.wdHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(Color.wdDanger)
                        .background(
                            Color.wdDanger.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                        )
                }
                .buttonStyle(WDPressableButtonStyle())

                Button(action: onAccept) {
                    Label("Doğru", systemImage: "checkmark")
                }
                .buttonStyle(WDProminentButtonStyle(.success))
            }
        }
        .padding()
        .wdScreenBackground()
    }

    private func answerRow(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: WDSpacing.md) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
                Text(value)
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
            }
            Spacer()
        }
        .padding(12)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ReviewAnswerView(
        word: "diligent",
        expectedAnswer: "çalışkan",
        givenAnswer: "çalşkn",
        onAccept: {},
        onReject: {}
    )
}
