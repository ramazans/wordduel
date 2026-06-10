import SwiftUI
import MatchEngine
import DesignSystem

struct AnsweringView: View {
    let word: String
    let startedAt: Date
    let durationSeconds: Int
    let onSubmit: (String) -> Void

    @State private var answer: String = ""
    @State private var hasSubmitted = false
    @State private var lastWarningTriggered = false
    @FocusState private var answerFocused: Bool

    private var countdown: Countdown {
        Countdown(startedAt: startedAt, durationSeconds: durationSeconds)
    }

    var body: some View {
        VStack(spacing: WDSpacing.lg) {
            timer

            WordCard(word: word)

            VStack(alignment: .leading, spacing: WDSpacing.sm) {
                TextField("Türkçe karşılığını yaz…", text: $answer)
                    .font(.wdBody)
                    .padding(14)
                    .background(
                        Color.wdSurfaceSecondary,
                        in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                            .strokeBorder(
                                answerFocused ? Color.wdAccent : Color.wdSeparator.opacity(0.4),
                                lineWidth: answerFocused ? 1.5 : 0.5
                            )
                    )
                    .focused($answerFocused)
                    .submitLabel(.send)
                    .disabled(hasSubmitted)
                    .onSubmit { submit(answer) }

                Text("Küçük yazım hataları sorun değil — rakibin değerlendirecek.")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
            }

            PrimaryButton("Gönder", systemImage: "paperplane.fill") {
                submit(answer)
            }
            .disabled(hasSubmitted || answer.trimmingCharacters(in: .whitespaces).isEmpty)

            Spacer()
        }
        .padding()
        .background(Color.wdBackground)
        .onAppear { answerFocused = true }
    }

    @ViewBuilder
    private var timer: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = countdown.remainingSeconds(now: context.date)
            let severity = countdown.severity(now: context.date)

            TimerRing(
                progress: Double(remaining) / Double(max(1, durationSeconds)),
                remainingSeconds: remaining,
                isCritical: severity != .normal
            )
            .sensoryFeedback(.warning, trigger: lastWarningTriggered)
            .onChange(of: severity) { _, newSeverity in
                handleSeverityChange(newSeverity)
            }
            .onChange(of: remaining) { _, newRemaining in
                if newRemaining == 0 && !hasSubmitted {
                    submit("")
                }
            }
        }
    }

    private func handleSeverityChange(_ severity: Countdown.Severity) {
        if severity == .warning && !lastWarningTriggered {
            lastWarningTriggered = true
        }
    }

    private func submit(_ value: String) {
        guard !hasSubmitted else { return }
        hasSubmitted = true
        onSubmit(value)
    }
}

#Preview("Normal") {
    AnsweringView(
        word: "ephemeral",
        startedAt: .now,
        durationSeconds: 30,
        onSubmit: { _ in }
    )
}

#Preview("About to expire") {
    AnsweringView(
        word: "diligent",
        startedAt: Date(timeIntervalSinceNow: -22),
        durationSeconds: 30,
        onSubmit: { _ in }
    )
}
