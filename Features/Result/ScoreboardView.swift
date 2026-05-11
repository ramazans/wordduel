import SwiftUI
import DesignSystem

struct ScoreboardView: View {
    let hostName: String
    let guestName: String
    let hostScore: Int
    let guestScore: Int
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    @State private var hasAppeared = false

    private var winner: Winner {
        if hostScore > guestScore { return .host }
        if guestScore > hostScore { return .guest }
        return .tie
    }

    enum Winner { case host, guest, tie }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            if winner != .tie {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.yellow)
                    .symbolEffect(.bounce, value: hasAppeared)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 32) {
                playerColumn(
                    name: hostName,
                    score: hostScore,
                    isWinner: winner == .host,
                    color: AvatarPalette.color(for: 0)
                )
                Text("—")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                playerColumn(
                    name: guestName,
                    score: guestScore,
                    isWinner: winner == .guest,
                    color: AvatarPalette.color(for: 1)
                )
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton("Tekrar Oyna", action: onPlayAgain)
                Button("Ana Ekran", action: onHome)
            }
            .padding(.horizontal)
        }
        .padding()
        .accessibilityLabel(scoreboardAccessibilityLabel)
        .onAppear {
            withAnimation(.spring(duration: 0.6).delay(0.2)) {
                hasAppeared = true
            }
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
    private func playerColumn(name: String, score: Int, isWinner: Bool, color: Color) -> some View {
        VStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(name.prefix(1).uppercased())
                        .font(.wdLargeTitle)
                        .foregroundStyle(.white)
                )
                .scaleEffect(isWinner && hasAppeared ? 1.1 : 1.0)
                .shadow(color: isWinner ? color.opacity(0.4) : .clear, radius: 8)
                .animation(.spring(duration: 0.6), value: hasAppeared)
                .accessibilityHidden(true)

            Text(name)
                .font(.wdHeadline)
            Text("\(score)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(isWinner ? Color.accentColor : Color.primary)
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
        onPlayAgain: {},
        onHome: {}
    )
}
