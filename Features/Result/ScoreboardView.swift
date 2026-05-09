import SwiftUI
import DesignSystem

struct ScoreboardView: View {
    let hostName: String
    let guestName: String
    let hostScore: Int
    let guestScore: Int
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    private var winner: Winner {
        if hostScore > guestScore { return .host }
        if guestScore > hostScore { return .guest }
        return .tie
    }

    enum Winner { case host, guest, tie }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            HStack(spacing: 32) {
                playerColumn(name: hostName, score: hostScore, isWinner: winner == .host, color: AvatarPalette.color(for: 0))
                Text("—")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                playerColumn(name: guestName, score: guestScore, isWinner: winner == .guest, color: AvatarPalette.color(for: 1))
            }

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton("Tekrar Oyna", action: onPlayAgain)
                Button("Ana Ekran", action: onHome)
            }
            .padding(.horizontal)
        }
        .padding()
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
                .symbolEffect(.bounce, value: isWinner)

            Text(name)
                .font(.wdHeadline)
            Text("\(score)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(isWinner ? .tint : .primary)
        }
    }
}

#Preview {
    ScoreboardView(
        hostName: "Ali",
        guestName: "Ayşe",
        hostScore: 14,
        guestScore: 8,
        onPlayAgain: {},
        onHome: {}
    )
}
