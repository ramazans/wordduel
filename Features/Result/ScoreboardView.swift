import SwiftUI
import DesignSystem

struct ScoreboardView: View {
    let hostName: String
    let guestName: String
    let hostScore: Int
    let guestScore: Int
    /// Bu cihazdaki oyuncunun maç sonucu — kutlama sesi ve konfeti buna göre seçilir.
    var localOutcome: LocalOutcome?
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

    var body: some View {
        VStack(spacing: WDSpacing.xl) {
            Spacer()

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
            .padding(.horizontal)

            Spacer()

            VStack(spacing: WDSpacing.sm) {
                PrimaryButton("Tekrar Oyna", systemImage: "arrow.counterclockwise", action: onPlayAgain)
                Button("Ana Ekrana Dön", action: onHome)
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInkSecondary)
                    .padding(.vertical, WDSpacing.sm)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(celebrationBackground)
        .overlay {
            if localOutcome == .won {
                ConfettiView()
                    .ignoresSafeArea()
            }
        }
        .accessibilityLabel(scoreboardAccessibilityLabel)
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

    private var celebrationBackground: some View {
        ZStack {
            Color.wdBackground
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
    ScoreboardView(
        hostName: "Ali",
        guestName: "Ayşe",
        hostScore: 14,
        guestScore: 8,
        localOutcome: .won,
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
        localOutcome: .tie,
        onPlayAgain: {},
        onHome: {}
    )
}
