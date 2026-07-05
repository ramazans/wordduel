import SwiftUI
import CoreModels
import DesignSystem

/// Biten maç özeti: kutlama başlığı, skor ve tur tur döküm
/// (kelime, beklenen/verilen cevap, kazandırdığı puan).
struct ScoreboardView: View {
    let hostName: String
    let guestName: String
    let hostScore: Int
    let guestScore: Int
    var rounds: [Round] = []
    var myRole: AskerRole?
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @State private var hasAppeared = false
    @State private var displayedHostScore = 0
    @State private var displayedGuestScore = 0

    private var winner: Winner {
        if hostScore > guestScore { return .host }
        if guestScore > hostScore { return .guest }
        return .tie
    }

    enum Winner { case host, guest, tie }

    enum LocalOutcome { case won, lost, tie }

    /// Bu cihazdaki oyuncunun maç sonucu — kutlama sesi ve konfeti buna göre seçilir.
    private var localOutcome: LocalOutcome? {
        guard let myRole else { return nil }
        switch winner {
        case .tie: return .tie
        case .host: return myRole == .host ? .won : .lost
        case .guest: return myRole == .guest ? .won : .lost
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: WDSpacing.lg) {
                celebrationHeader

                scoreCard

                if !sortedRounds.isEmpty {
                    roundBreakdown
                }

                VStack(spacing: WDSpacing.sm) {
                    PrimaryButton("Tekrar Oyna", systemImage: "arrow.counterclockwise", action: onPlayAgain)
                    Button("Ana Ekrana Dön", action: onHome)
                        .font(.wdHeadline)
                        .foregroundStyle(Color.wdInkSecondary)
                        .padding(.vertical, WDSpacing.sm)
                }
            }
            .padding()
        }
        .background(celebrationBackground)
        .overlay {
            if localOutcome == .won {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6).delay(0.2)) {
                hasAppeared = true
            }
            withAnimation(.snappy(duration: 1.0).delay(0.4)) {
                displayedHostScore = hostScore
                displayedGuestScore = guestScore
            }
            playOutcomeSound()
        }
    }

    private func playOutcomeSound() {
        switch localOutcome {
        case .won: SoundPlayer.shared.play(.victory)
        case .lost: SoundPlayer.shared.play(.defeat)
        case .tie: SoundPlayer.shared.play(.tie)
        case nil: break
        }
    }

    // MARK: - Kutlama başlığı

    private var celebrationHeader: some View {
        VStack(spacing: WDSpacing.md) {
            if winner == .tie {
                Image(systemName: "equal.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Color.wdInkSecondary)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(LinearGradient.wdGoldGradient)
                    .symbolEffect(.bounce, value: hasAppeared)
                    .shadow(color: Color.wdGold.opacity(0.4), radius: 12, x: 0, y: 4)
                    .accessibilityHidden(true)
            }

            Text(resultTitle)
                .font(.wdLargeTitle)
                .foregroundStyle(Color.wdInk)
                .multilineTextAlignment(.center)
            Text(resultSubtitle)
                .font(.wdSubheadline)
                .foregroundStyle(Color.wdInkSecondary)
        }
        .padding(.top, WDSpacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(scoreboardAccessibilityLabel)
    }

    private var scoreCard: some View {
        HStack(alignment: .top) {
            playerColumn(
                name: hostName,
                score: displayedHostScore,
                isWinner: winner == .host,
                colorIndex: 0
            )
            .frame(maxWidth: .infinity)

            Text("VS")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(Color.wdInkSecondary)
                .padding(.top, WDSpacing.xl)
                .accessibilityHidden(true)

            playerColumn(
                name: guestName,
                score: displayedGuestScore,
                isWinner: winner == .guest,
                colorIndex: 1
            )
            .frame(maxWidth: .infinity)
        }
        .wdCard(padding: WDSpacing.lg)
    }

    // MARK: - Tur dökümü

    private var sortedRounds: [Round] {
        rounds.sorted { $0.index < $1.index }
    }

    private var roundBreakdown: some View {
        VStack(alignment: .leading, spacing: WDSpacing.sm) {
            Text("Tur Dökümü")
                .font(.wdTitle)
                .foregroundStyle(Color.wdInk)

            VStack(spacing: WDSpacing.sm) {
                ForEach(sortedRounds, id: \.index) { round in
                    roundRow(round)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roundRow(_ round: Round) -> some View {
        let wasCorrect = round.judgement == .correct

        return HStack(alignment: .top, spacing: WDSpacing.md) {
            Image(systemName: wasCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(wasCorrect ? Color.wdSuccess : Color.wdDanger)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: WDSpacing.sm) {
                    Text("Tur \(round.index + 1)")
                        .font(.wdLabel)
                        .foregroundStyle(Color.wdInkSecondary)
                    if round.isRepeat {
                        Label("Tekrar", systemImage: "arrow.clockwise")
                            .font(.wdLabel)
                            .foregroundStyle(Color.wdWarning)
                    }
                }
                Text(round.word)
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
                Text("Beklenen: \(round.expectedAnswer)")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
                Text("Cevap: \(round.answerGiven ?? "cevapsız")")
                    .font(.wdCaption)
                    .foregroundStyle(wasCorrect ? Color.wdSuccess : Color.wdInkSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if wasCorrect {
                    Text("Bildi")
                        .font(.wdLabel)
                        .foregroundStyle(Color.wdSuccess)
                    Text("puan yok")
                        .font(.wdCaption)
                        .foregroundStyle(Color.wdInkSecondary)
                } else {
                    Text("+\(round.pointsAwarded)")
                        .font(.system(.title3, design: .rounded).weight(.heavy))
                        .foregroundStyle(Color.wdAccent)
                        .monospacedDigit()
                    Text(beneficiaryName(of: round))
                        .font(.wdCaption)
                        .foregroundStyle(Color.wdInkSecondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.wdSurfaceSecondary,
            in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(roundAccessibilityLabel(round))
    }

    /// Yanlış cevapta puanı soran taraf kazanır.
    private func beneficiaryName(of round: Round) -> String {
        if let myRole {
            return round.askerRole == myRole ? "sana" : "rakibe"
        }
        return round.askerRole == .host ? hostName : guestName
    }

    private func roundAccessibilityLabel(_ round: Round) -> String {
        let result = round.judgement == .correct
            ? "bilindi, puan yok"
            : "bilinemedi, \(round.pointsAwarded) puan \(beneficiaryName(of: round))"
        return "Tur \(round.index + 1): \(round.word), beklenen \(round.expectedAnswer), cevap \(round.answerGiven ?? "cevapsız"), \(result)"
    }

    // MARK: - Yardımcılar

    private var celebrationBackground: some View {
        ZStack {
            LinearGradient.wdScreenGradient
            RadialGradient(
                colors: [accentForWinner.opacity(0.18), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private var accentForWinner: Color {
        switch winner {
        case .host: return AvatarPalette.color(for: 0)
        case .guest: return AvatarPalette.color(for: 1)
        case .tie: return .wdAccent
        }
    }

    private var resultTitle: String {
        switch winner {
        case .host: return "\(hostName) kazandı!"
        case .guest: return "\(guestName) kazandı!"
        case .tie: return "Beraberlik!"
        }
    }

    private var resultSubtitle: String {
        switch winner {
        case .host, .guest: return "Rövanş için yeni maç başlatın."
        case .tie: return "Bu rekabet böyle bitmez — rövanş şart."
        }
    }

    private var scoreboardAccessibilityLabel: String {
        let result: String = {
            switch winner {
            case .host: return "Kazanan: \(hostName)"
            case .guest: return "Kazanan: \(guestName)"
            case .tie: return "Beraberlik"
            }
        }()
        return "\(result). \(hostName): \(hostScore) puan. \(guestName): \(guestScore) puan."
    }

    @ViewBuilder
    private func playerColumn(name: String, score: Int, isWinner: Bool, colorIndex: Int) -> some View {
        VStack(spacing: WDSpacing.sm) {
            AvatarView(
                name: name,
                colorIndex: colorIndex,
                size: 72,
                isHighlighted: isWinner
            )
            .scaleEffect(isWinner && hasAppeared ? 1.08 : 1.0)
            .animation(.spring(duration: 0.6), value: hasAppeared)

            Text(name)
                .font(.wdHeadline)
                .foregroundStyle(Color.wdInk)
                .lineLimit(1)

            Text("\(score)")
                .font(.wdScore)
                .foregroundStyle(isWinner ? Color.wdAccent : Color.wdInk)
                .contentTransition(.numericText(value: Double(score)))
        }
    }
}

#Preview("Host wins") {
    let r1 = Round(index: 0, askerRole: .host, word: "ephemeral", expectedAnswer: "geçici")
    r1.answerGiven = "kalıcı"
    r1.judgementRaw = Judgement.wrong.rawValue
    r1.pointsAwarded = 2
    let r2 = Round(index: 1, askerRole: .guest, word: "diligent", expectedAnswer: "çalışkan")
    r2.answerGiven = "çalışkan"
    r2.judgementRaw = Judgement.correct.rawValue
    let r3 = Round(index: 3, askerRole: .host, word: "ephemeral", expectedAnswer: "geçici", isRepeat: true, originRoundIndex: 0)
    r3.judgementRaw = Judgement.wrong.rawValue
    r3.pointsAwarded = 4

    return ScoreboardView(
        hostName: "Ali",
        guestName: "Ayşe",
        hostScore: 14,
        guestScore: 8,
        rounds: [r1, r2, r3],
        myRole: .host,
        onPlayAgain: {},
        onHome: {}
    )
}

#Preview("Tie") {
    ScoreboardView(
        hostName: "Ali",
        guestName: "Ayşe",
        hostScore: 6,
        guestScore: 6,
        myRole: .host,
        onPlayAgain: {},
        onHome: {}
    )
}
