import SwiftUI
import CoreModels
import MatchEngine
import DesignSystem

struct AnsweringView: View {
    let word: String
    let startedAt: Date
    let durationSeconds: Int
    var format: AnswerFormat = .text
    var options: [String] = []
    /// "Deyim" / "Phrasal Verb" — düz kelimede nil.
    var kindLabel: String?
    let onSubmit: (String) -> Void

    @State private var answer: String = ""
    @State private var hasSubmitted = false
    @State private var selectedOption: String?
    @State private var lastWarningTriggered = false
    @FocusState private var answerFocused: Bool

    private var countdown: Countdown {
        Countdown(startedAt: startedAt, durationSeconds: durationSeconds)
    }

    private var isMultipleChoice: Bool {
        format == .multipleChoice && options.count >= 2
    }

    var body: some View {
        VStack(spacing: WDSpacing.lg) {
            timer

            WordCard(word: word, hint: kindLabel)

            if isMultipleChoice {
                optionButtons
            } else {
                freeTextInput

                PrimaryButton("Gönder", systemImage: "paperplane.fill") {
                    submit(answer)
                }
                .disabled(hasSubmitted || answer.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()
        }
        .padding()
        .background(Color.wdBackground)
        .onAppear {
            if !isMultipleChoice { answerFocused = true }
        }
    }

    // MARK: - Serbest metin

    private var freeTextInput: some View {
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
    }

    // MARK: - Çoktan seçmeli

    /// 4 şık; dokunmak cevabı anında gönderir (yazım hatası olamayacağı için
    /// onay adımı yok). Gönderim sonrası tüm şıklar kilitlenir.
    private var optionButtons: some View {
        VStack(spacing: WDSpacing.sm) {
            ForEach(options, id: \.self) { option in
                Button {
                    selectedOption = option
                    submit(option)
                } label: {
                    Text(option)
                        .font(.wdHeadline)
                        .foregroundStyle(Color.wdInk)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(
                            Color.wdSurfaceSecondary,
                            in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
                                .strokeBorder(
                                    selectedOption == option ? Color.wdAccent : Color.wdSeparator.opacity(0.4),
                                    lineWidth: selectedOption == option ? 1.5 : 0.5
                                )
                        )
                }
                .buttonStyle(WDPressableButtonStyle())
                .disabled(hasSubmitted)
                .accessibilityHint("Bu şıkkı cevap olarak gönderir")
            }
        }
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
                guard !hasSubmitted else { return }
                if newRemaining == 0 {
                    SoundPlayer.shared.play(.timeUp)
                    submit("")
                } else if newRemaining <= 10 {
                    SoundPlayer.shared.play(.tick)
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
        if !value.trimmingCharacters(in: .whitespaces).isEmpty {
            SoundPlayer.shared.play(.send)
        }
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
