import SwiftUI
import DesignSystem

struct ReviewAnswerView: View {
    let word: String
    let expectedAnswer: String
    let givenAnswer: String
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Cevabı Değerlendir")
                .font(.wdTitle)

            VStack(alignment: .leading, spacing: 12) {
                LabeledContent("Kelime", value: word)
                LabeledContent("Beklenen", value: expectedAnswer)
                LabeledContent("Verilen", value: givenAnswer.isEmpty ? "—" : givenAnswer)
            }
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))

            HStack(spacing: 12) {
                Button(role: .destructive, action: onReject) {
                    Label("Yanlış say", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: onAccept) {
                    Label("Doğru say", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        }
        .padding()
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
