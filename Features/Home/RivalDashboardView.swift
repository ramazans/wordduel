import SwiftUI
import SwiftData
import CoreModels
import CloudKitService
import AuthService
import DesignSystem

/// Tek bir rakibe özel dashboard: kafa kafaya skor kartı, o rakiple devam
/// eden maçlar ve maç geçmişi. Ana sayfadaki rakip listesinden açılır.
struct RivalDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Environment(AuthController.self) private var authController
    @Query(sort: \Match.createdAt, order: .reverse) private var allMatches: [Match]
    @Query private var players: [Player]

    let opponent: Player

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WDSpacing.lg) {
                rivalryCard

                if !activeMatches.isEmpty {
                    section("Devam eden maçlar") {
                        ForEach(activeMatches) { match in
                            activeMatchRow(match)
                        }
                    }
                }

                if !finishedMatches.isEmpty {
                    section("Geçmiş") {
                        ForEach(finishedMatches) { match in
                            finishedMatchRow(match)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, WDSpacing.md)
        }
        .wdScreenBackground()
        .navigationTitle(opponent.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await pullRemoteUpdates() }
    }

    // MARK: - Rekabet kartı

    /// Kafa kafaya rekabet kartı: ben vs bu rakip, toplam galibiyetler.
    private var rivalryCard: some View {
        let record = headToHeadRecord

        return VStack(spacing: WDSpacing.md) {
            Text("Ezeli Rekabet")
                .font(.wdLabel)
                .foregroundStyle(Color.wdInkSecondary)
                .textCase(.uppercase)

            HStack(alignment: .top) {
                rivalryColumn(
                    name: me?.displayName ?? "Sen",
                    colorIndex: me?.avatarColor ?? 0,
                    wins: record.wins,
                    isLeading: record.wins > record.losses
                )
                .frame(maxWidth: .infinity)

                Text("VS")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(Color.wdInkSecondary)
                    .padding(.top, WDSpacing.md)
                    .accessibilityHidden(true)

                rivalryColumn(
                    name: opponent.displayName,
                    colorIndex: opponent.avatarColor,
                    wins: record.losses,
                    isLeading: record.losses > record.wins
                )
                .frame(maxWidth: .infinity)
            }

            if record.draws > 0 {
                Text("\(record.draws) beraberlik")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .wdCard(padding: WDSpacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Rekabet: \(me?.displayName ?? "Sen") \(record.wins) galibiyet, \(opponent.displayName) \(record.losses) galibiyet, \(record.draws) beraberlik"
        )
    }

    private func rivalryColumn(name: String, colorIndex: Int, wins: Int, isLeading: Bool) -> some View {
        VStack(spacing: WDSpacing.sm) {
            AvatarView(name: name, colorIndex: colorIndex, size: 64, isHighlighted: isLeading)
            Text(name)
                .font(.wdHeadline)
                .foregroundStyle(Color.wdInk)
                .lineLimit(1)
            Text("\(wins)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(isLeading ? Color.wdAccent : Color.wdInk)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Maç satırları

    private func activeMatchRow(_ match: Match) -> some View {
        let myTurn = isMyTurn(match)

        return NavigationLink {
            MatchDetailView(match: match)
        } label: {
            HStack(spacing: WDSpacing.md) {
                Image(systemName: "flag.2.crossed")
                    .font(.title3)
                    .foregroundStyle(Color.wdAccent)
                    .frame(width: 44, height: 44)
                    .background(Color.wdAccent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Tur \(match.currentRoundIndex + 1)/\(match.totalRounds)")
                        .font(.wdHeadline)
                        .foregroundStyle(Color.wdInk)
                    Text(match.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.wdCaption)
                        .foregroundStyle(Color.wdInkSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(stats.myScore(in: match)) – \(stats.opponentScore(in: match))")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.wdInk)
                    if myTurn {
                        Text("Sıra sende")
                            .font(.wdLabel)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.wdAccent, in: Capsule())
                    }
                }
            }
            .wdCard()
            .overlay {
                if myTurn {
                    RoundedRectangle(cornerRadius: WDRadius.lg, style: .continuous)
                        .strokeBorder(Color.wdAccent.opacity(0.5), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(WDPressableButtonStyle())
        .accessibilityLabel(
            "Devam eden maç, tur \(match.currentRoundIndex + 1) / \(match.totalRounds), skor \(stats.myScore(in: match)) - \(stats.opponentScore(in: match))\(myTurn ? ", sıra sende" : "")"
        )
    }

    private func finishedMatchRow(_ match: Match) -> some View {
        let outcome = stats.outcome(of: match)

        return NavigationLink {
            MatchDetailView(match: match)
        } label: {
            HStack(spacing: WDSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(stats.myScore(in: match)) – \(stats.opponentScore(in: match))")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Color.wdInk)
                    if let date = match.finishedAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.wdCaption)
                            .foregroundStyle(Color.wdInkSecondary)
                    }
                }

                Spacer()

                outcomeBadge(outcome)
            }
            .wdCard()
        }
        .buttonStyle(WDPressableButtonStyle())
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

    private func section(_ title: LocalizedStringKey, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: WDSpacing.sm) {
            Text(title)
                .font(.wdTitle)
                .foregroundStyle(Color.wdInk)
            rows()
        }
    }

    // MARK: - Veri

    private var stats: MatchStats {
        MatchStats(myAppleUserID: myAppleUserID)
    }

    /// Bu rakiple oynanan tüm maçlar (en yeni başta).
    private var opponentMatches: [Match] {
        allMatches.filter { stats.opponent(in: $0)?.appleUserID == opponent.appleUserID }
    }

    private var activeMatches: [Match] {
        opponentMatches.filter { $0.status == .active }
    }

    private var finishedMatches: [Match] {
        opponentMatches
            .filter { $0.status == .finished }
            .sorted { ($0.finishedAt ?? $0.createdAt) > ($1.finishedAt ?? $1.createdAt) }
    }

    private var headToHeadRecord: (wins: Int, draws: Int, losses: Int) {
        stats.record(for: opponentMatches)
    }

    private var me: Player? {
        guard let myAppleUserID else { return players.first }
        return players.first { $0.appleUserID == myAppleUserID }
    }

    private var myAppleUserID: String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
    }

    /// Faza göre aksiyon bende mi: kelime seçme, cevaplama veya değerlendirme.
    private func isMyTurn(_ match: Match) -> Bool {
        guard let myRole = stats.role(in: match) else { return false }
        let flow = MatchFlow(match: match)
        switch flow.phase {
        case .picking(let asker):
            return asker == myRole
        case .answering:
            return flow.currentRound?.askerRole != myRole
        case .reviewing:
            return flow.currentRound?.askerRole == myRole
        case .waitingForOpponent, .finished:
            return false
        }
    }

    /// Bu rakiple bitmemiş maçların uzak revizyonlarını indirir.
    private func pullRemoteUpdates() async {
        let repository = services.matchSyncService.stateRepository
        for match in opponentMatches where match.status != .finished {
            await MatchCloudSync.pull(match, repository: repository, context: modelContext)
        }
    }

    private func accessibilityLabel(for match: Match, outcome: MatchStats.Outcome) -> String {
        let result: String = {
            switch outcome {
            case .win: return "kazandın"
            case .loss: return "kaybettin"
            case .draw: return "berabere"
            }
        }()
        return "\(opponent.displayName) ile maç, \(stats.myScore(in: match)) - \(stats.opponentScore(in: match)), \(result)"
    }
}

#Preview {
    NavigationStack {
        RivalDashboardView(opponent: Player(appleUserID: "preview", displayName: "Gizem", avatarColor: 3))
    }
    .modelContainer(for: [Match.self, Player.self, Round.self], inMemory: true)
    .environment(AuthController())
}
