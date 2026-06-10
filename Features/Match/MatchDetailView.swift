import SwiftUI
import SwiftData
import CoreModels
import AuthService
import MatchEngine
import DesignSystem

/// Canlı maç ekranı: faza göre kelime seçme, cevaplama, değerlendirme,
/// bekleme ve skor tablosu durumları arasında geçiş yapar.
struct MatchDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController
    @Environment(\.dismiss) private var dismiss

    let match: Match
    var onPlayAgain: () -> Void = {}

    var body: some View {
        Group {
            if case .finished = flow.phase {
                ScoreboardView(
                    hostName: match.host?.displayName ?? "Host",
                    guestName: match.guest?.displayName ?? "Misafir",
                    hostScore: match.hostScore,
                    guestScore: match.guestScore,
                    onPlayAgain: {
                        dismiss()
                        onPlayAgain()
                    },
                    onHome: { dismiss() }
                )
                .navigationBarBackButtonHidden()
            } else {
                VStack(spacing: WDSpacing.md) {
                    scoreHeader

                    if let last = flow.lastResolvedRound {
                        resultBanner(last)
                    }

                    phaseContent
                        .frame(maxHeight: .infinity)
                }
                .padding(.top, WDSpacing.sm)
                .background(Color.wdBackground)
                .navigationTitle(opponent?.displayName ?? "Maç")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .animation(.snappy, value: flow.phase)
    }

    // MARK: - Faz içeriği

    @ViewBuilder
    private var phaseContent: some View {
        switch flow.phase {
        case .waitingForOpponent:
            waitingForOpponentCard

        case .picking(let asker):
            if asker == myRole {
                AskingView(
                    roundNumber: match.currentRoundIndex + 1,
                    totalRounds: match.totalRounds,
                    dueRepeats: flow.dueRepeats(for: asker),
                    onAsk: { word, expected in
                        flow.askWord(word, expectedAnswer: expected, asker: asker)
                        save()
                    },
                    onAskRepeat: { item in
                        flow.askRepeat(item, asker: asker)
                        save()
                    }
                )
            } else {
                waitingCard(
                    systemImage: "text.magnifyingglass",
                    title: "\(opponent?.displayName ?? "Rakip") kelime seçiyor",
                    subtitle: "Sorulacak kelime belirlenince sıra sana gelecek."
                )
            }

        case .answering:
            if let round = flow.currentRound {
                if round.askerRole == myRole {
                    askerWaitingView(round)
                } else {
                    AnsweringView(
                        word: round.word,
                        startedAt: round.startedAt ?? .now,
                        durationSeconds: match.roundTimerSeconds,
                        onSubmit: { answer in
                            flow.submitAnswer(answer)
                            save()
                        }
                    )
                    .id("answering-\(round.index)")
                }
            }

        case .reviewing:
            if let round = flow.currentRound {
                if round.askerRole == myRole {
                    ReviewAnswerView(
                        word: round.word,
                        expectedAnswer: round.expectedAnswer,
                        givenAnswer: round.answerGiven ?? "",
                        onAccept: {
                            flow.review(isCorrect: true)
                            save()
                        },
                        onReject: {
                            flow.review(isCorrect: false)
                            save()
                        }
                    )
                } else {
                    waitingCard(
                        systemImage: "person.fill.questionmark",
                        title: "\(opponent?.displayName ?? "Rakip") değerlendiriyor",
                        subtitle: "Cevabın doğru sayılıp sayılmayacağına karar veriyor."
                    )
                }
            }

        case .finished:
            EmptyView()
        }
    }

    // MARK: - Üst skor şeridi

    private var scoreHeader: some View {
        HStack(spacing: WDSpacing.md) {
            scoreColumn(
                name: me?.displayName ?? "Sen",
                colorIndex: me?.avatarColor ?? 0,
                score: stats.myScore(in: match)
            )

            VStack(spacing: 2) {
                Text("TUR")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.wdInkSecondary)
                Text("\(min(match.currentRoundIndex + 1, match.totalRounds))/\(match.totalRounds)")
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
                    .monospacedDigit()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.wdSurfaceSecondary, in: Capsule())

            scoreColumn(
                name: opponent?.displayName ?? "Rakip",
                colorIndex: opponent?.avatarColor ?? 1,
                score: stats.opponentScore(in: match)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Skor: sen \(stats.myScore(in: match)), \(opponent?.displayName ?? "rakip") \(stats.opponentScore(in: match)), tur \(min(match.currentRoundIndex + 1, match.totalRounds)) / \(match.totalRounds)"
        )
    }

    private func scoreColumn(name: String, colorIndex: Int, score: Int) -> some View {
        HStack(spacing: WDSpacing.sm) {
            AvatarView(name: name, colorIndex: colorIndex, size: 36)
            Text("\(score)")
                .font(.system(.title2, design: .rounded).weight(.heavy))
                .foregroundStyle(Color.wdInk)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Son tur sonucu

    private func resultBanner(_ round: Round) -> some View {
        let wasCorrect = round.judgement == .correct
        let text: String = if wasCorrect {
            "\"\(round.word)\" bilindi — puan yok"
        } else if round.askerRole == myRole {
            "\"\(round.word)\" bilinemedi — +\(round.pointsAwarded) puan sana"
        } else {
            "\"\(round.word)\" bilinemedi — +\(round.pointsAwarded) puan rakibe"
        }

        return HStack(spacing: WDSpacing.sm) {
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(wasCorrect ? Color.wdSuccess : Color.wdDanger)
            Text(text)
                .font(.wdCaption)
                .foregroundStyle(Color.wdInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
        }
        .padding(.horizontal, WDSpacing.md)
        .padding(.vertical, WDSpacing.sm)
        .background(
            (wasCorrect ? Color.wdSuccess : Color.wdDanger).opacity(0.08),
            in: Capsule()
        )
        .padding(.horizontal)
        .accessibilityLabel("Son tur: \(text)")
    }

    // MARK: - Bekleme durumları

    private var waitingForOpponentCard: some View {
        VStack(spacing: WDSpacing.lg) {
            Image(systemName: "hourglass")
                .font(.system(size: 40))
                .foregroundStyle(Color.wdWarning)
                .frame(width: 88, height: 88)
                .background(Color.wdWarning.opacity(0.12), in: Circle())

            VStack(spacing: WDSpacing.xs) {
                Text("Rakip bekleniyor")
                    .font(.wdTitle)
                    .foregroundStyle(Color.wdInk)
                Text("Arkadaşın kodu girip katıldığında maç otomatik başlar.")
                    .font(.wdSubheadline)
                    .foregroundStyle(Color.wdInkSecondary)
                    .multilineTextAlignment(.center)
            }

            CodeDigitsView(match.code)

            ShareLink(item: "WordDuel'de seninle kelime düellosu yapmak istiyorum! Davet kodum: \(match.code)") {
                Label("Daveti Paylaş", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(WDProminentButtonStyle(.primary))
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private func waitingCard(systemImage: String, title: String, subtitle: String) -> some View {
        VStack(spacing: WDSpacing.lg) {
            Spacer()
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(Color.wdAccent)
                .frame(width: 88, height: 88)
                .background(Color.wdAccent.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: WDSpacing.xs) {
                Text(title)
                    .font(.wdTitle)
                    .foregroundStyle(Color.wdInk)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.wdSubheadline)
                    .foregroundStyle(Color.wdInkSecondary)
                    .multilineTextAlignment(.center)
            }

            ProgressView()
                .padding(.top, WDSpacing.sm)
            Spacer()
            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
    }

    /// Asker, rakibinin cevabını geri sayımla bekler; süre + pay dolarsa
    /// turu tek taraflı kapatabilir (rakibin cihazı kapalıysa maç kilitlenmesin).
    private func askerWaitingView(_ round: Round) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let countdown = Countdown(
                startedAt: round.startedAt ?? .now,
                durationSeconds: match.roundTimerSeconds
            )
            let remaining = countdown.remainingSeconds(now: context.date)

            VStack(spacing: WDSpacing.lg) {
                Spacer()

                TimerRing(
                    progress: Double(remaining) / Double(max(1, match.roundTimerSeconds)),
                    remainingSeconds: remaining,
                    isCritical: countdown.severity(now: context.date) != .normal
                )

                VStack(spacing: WDSpacing.xs) {
                    Text("\(opponent?.displayName ?? "Rakip") cevaplıyor")
                        .font(.wdTitle)
                        .foregroundStyle(Color.wdInk)
                    Text("Sorduğun kelime: \"\(round.word)\"")
                        .font(.wdSubheadline)
                        .foregroundStyle(Color.wdInkSecondary)
                }

                if flow.answerDeadlinePassed(now: context.date) {
                    VStack(spacing: WDSpacing.sm) {
                        Text("Süre doldu, cevap gelmedi.")
                            .font(.wdCaption)
                            .foregroundStyle(Color.wdInkSecondary)
                        PrimaryButton("Turu Kapat", systemImage: "flag.checkered") {
                            flow.resolveTimeout()
                            save()
                        }
                        .padding(.horizontal)
                    }
                }

                Spacer()
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Yardımcılar

    private var flow: MatchFlow { MatchFlow(match: match) }

    private var stats: MatchStats { MatchStats(myAppleUserID: myAppleUserID) }

    private var myAppleUserID: String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
    }

    private var myRole: AskerRole? { stats.role(in: match) }

    private var me: Player? {
        myRole == .guest ? match.guest : match.host
    }

    private var opponent: Player? { stats.opponent(in: match) }

    private func save() {
        try? modelContext.save()
    }
}

#Preview {
    NavigationStack {
        MatchDetailView(match: Match(code: "AB23K9"))
    }
    .modelContainer(for: [Match.self, Player.self, Round.self], inMemory: true)
    .environment(AuthController())
}
