import SwiftUI
import SwiftData
import CoreModels
import AuthService
import DesignSystem

struct HistoryView: View {
    @Environment(AuthController.self) private var authController
    @Query(filter: #Predicate<Match> { $0.statusRaw == "finished" },
           sort: \Match.finishedAt, order: .reverse)
    private var finishedMatches: [Match]

    var body: some View {
        Group {
            if finishedMatches.isEmpty {
                ContentUnavailableView(
                    "Geçmiş yok",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("İlk maçını bitirdiğinde sonuçlar burada birikecek.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: WDSpacing.sm) {
                        ForEach(finishedMatches) { match in
                            NavigationLink {
                                MatchDetailView(match: match)
                            } label: {
                                historyCard(match)
                            }
                            .buttonStyle(WDPressableButtonStyle())
                        }
                    }
                    .padding()
                }
            }
        }
        .wdScreenBackground()
        .navigationTitle("Geçmiş")
    }

    private func historyCard(_ match: Match) -> some View {
        let stats = MatchStats(myAppleUserID: myAppleUserID)
        let outcome = stats.outcome(of: match)
        let opponent = stats.opponent(in: match)

        return HStack(spacing: WDSpacing.md) {
            AvatarView(
                name: opponent?.displayName ?? "?",
                colorIndex: opponent?.avatarColor ?? 1,
                size: 44
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(opponent?.displayName ?? "Rakip")
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
                if let date = match.finishedAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.wdCaption)
                        .foregroundStyle(Color.wdInkSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stats.myScore(in: match)) – \(stats.opponentScore(in: match))")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.wdInk)
                outcomeBadge(outcome)
            }
        }
        .wdCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: match, outcome: outcome))
    }

    @ViewBuilder
    private func outcomeBadge(_ outcome: MatchStats.Outcome) -> some View {
        let (text, tint): (String, Color) = {
            switch outcome {
            case .win: return ("Kazandın", .wdSuccess)
            case .loss: return ("Kaybettin", .wdDanger)
            case .draw: return ("Berabere", .wdInkSecondary)
            }
        }()

        Text(text)
            .font(.wdLabel)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func accessibilityLabel(for match: Match, outcome: MatchStats.Outcome) -> String {
        let stats = MatchStats(myAppleUserID: myAppleUserID)
        let opponentName = stats.opponent(in: match)?.displayName ?? "Rakip"
        let result: String = {
            switch outcome {
            case .win: return "kazandın"
            case .loss: return "kaybettin"
            case .draw: return "berabere"
            }
        }()
        return "\(opponentName) ile maç, \(stats.myScore(in: match)) - \(stats.opponentScore(in: match)), \(result)"
    }

    private var myAppleUserID: String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
    }
}

#Preview {
    NavigationStack { HistoryView() }
        .modelContainer(for: [Match.self], inMemory: true)
        .environment(AuthController())
}
