import SwiftUI
import DesignSystem

struct AnsweringView: View {
    let word: String
    let startedAt: Date
    let durationSeconds: Int
    @State private var answer: String = ""
    let onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 24) {
            TimelineView(.periodic(from: .now, by: 1.0)) { context in
                let remaining = remainingSeconds(now: context.date)
                Text("\(remaining) sn kaldı")
                    .font(.wdHeadline)
                    .monospacedDigit()
                    .foregroundStyle(remaining <= 10 ? .wdTimerCritical : .wdTimerNormal)
                    .accessibilityLabel("Kalan süre \(remaining) saniye")
                    .onChange(of: remaining) { _, newValue in
                        if newValue <= 0 {
                            onSubmit("")
                        }
                    }
            }

            WordCard(word: word)

            TextField("Türkçe karşılık", text: $answer)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit {
                    onSubmit(answer)
                }

            PrimaryButton("Gönder") {
                onSubmit(answer)
            }
            .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    private func remainingSeconds(now: Date) -> Int {
        let elapsed = Int(now.timeIntervalSince(startedAt))
        return max(0, durationSeconds - elapsed)
    }
}

#Preview {
    AnsweringView(
        word: "ephemeral",
        startedAt: .now,
        durationSeconds: 30,
        onSubmit: { _ in }
    )
}
