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

    private var countdown: Countdown {
        Countdown(startedAt: startedAt, durationSeconds: durationSeconds)
    }

    var body: some View {
        VStack(spacing: 24) {
            timer

            WordCard(word: word)

            TextField("Türkçe karşılık", text: $answer)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .disabled(hasSubmitted)
                .onSubmit { submit(answer) }

            PrimaryButton("Gönder") {
                submit(answer)
            }
            .disabled(hasSubmitted || answer.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    @ViewBuilder
    private var timer: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let remaining = countdown.remainingSeconds(now: context.date)
            let severity = countdown.severity(now: context.date)

            Text(String(format: NSLocalizedString("match.timeLeft", comment: ""), remaining))
                .font(.wdHeadline)
                .monospacedDigit()
                .foregroundStyle(color(for: severity))
                .accessibilityLabel("Kalan süre \(remaining) saniye")
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

    private func color(for severity: Countdown.Severity) -> Color {
        switch severity {
        case .normal: return .wdTimerNormal
        case .warning: return .wdTimerCritical
        case .expired: return .wdTimerCritical
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
