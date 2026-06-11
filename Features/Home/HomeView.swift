import SwiftUI
import SwiftData
import CoreModels
import CloudKitService
import AuthService
import DesignSystem

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Environment(AuthController.self) private var authController
    @Query(sort: \Match.createdAt, order: .reverse) private var matches: [Match]
    @Query private var players: [Player]
    @State private var viewModel: HomeViewModel?
    @State private var showJoinSheet = false
    @State private var reinvite: ReinviteCode?

    private struct ReinviteCode: Identifiable {
        let code: String
        var id: String { code }
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.wdBackground)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { profileToolbar }
                .safeAreaInset(edge: .bottom) { actionBar }
                .sheet(isPresented: createdBinding) {
                    if case .created(let code, _) = viewModel?.createState {
                        InviteView(code: code) {
                            viewModel?.dismissCreatedSheet()
                        }
                        .presentationDetents([.medium])
                    }
                }
                .sheet(item: $reinvite) { invite in
                    InviteView(code: invite.code) {
                        reinvite = nil
                    }
                    .presentationDetents([.medium])
                }
                .sheet(isPresented: $showJoinSheet) {
                    JoinByCodeView(syncService: services.matchSyncService)
                        .presentationDetents([.medium])
                }
                .task {
                    if viewModel == nil {
                        viewModel = HomeViewModel(syncService: services.matchSyncService)
                    }
                    claimGuestSeats()
                    await scheduleTurnNotifications()
                }
                .task {
                    for await _ in services.pushUpdates {
                        claimGuestSeats()
                        await scheduleTurnNotifications()
                    }
                }
        }
    }

    // MARK: - Layout

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WDSpacing.lg) {
                greetingHeader

                if let rival {
                    rivalryCard(rival: rival)
                } else {
                    inviteTeaserCard
                }

                if case .error(let message) = viewModel?.createState {
                    errorBanner(message)
                }

                matchSections
            }
            .padding(.horizontal)
            .padding(.bottom, WDSpacing.md)
        }
        .refreshable {
            claimGuestSeats()
            await scheduleTurnNotifications()
        }
    }

    @ToolbarContentBuilder
    private var profileToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                ProfileView()
            } label: {
                AvatarView(
                    name: me?.displayName ?? "?",
                    colorIndex: me?.avatarColor ?? 0,
                    size: 34
                )
            }
            .accessibilityLabel("Profil")
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: WDSpacing.xs) {
            Text(greetingTitle)
                .font(.wdDisplay)
                .foregroundStyle(Color.wdInk)
            Text(greetingSubtitle)
                .font(.wdSubheadline)
                .foregroundStyle(Color.wdInkSecondary)
        }
        .padding(.top, WDSpacing.sm)
        .accessibilityElement(children: .combine)
    }

    /// Kafa kafaya rekabet kartı: ben vs rakibim, toplam galibiyetler.
    private func rivalryCard(rival: Player) -> some View {
        let stats = MatchStats(myAppleUserID: myAppleUserID())
        let record = stats.record(for: matches)
        let rivalWins = record.losses

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
                    isLeading: record.wins > rivalWins
                )
                .frame(maxWidth: .infinity)

                Text("VS")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(LinearGradient.wdAccentGradient, in: Circle())
                    .padding(.top, WDSpacing.md)
                    .accessibilityHidden(true)

                rivalryColumn(
                    name: rival.displayName,
                    colorIndex: rival.avatarColor,
                    wins: rivalWins,
                    isLeading: rivalWins > record.wins
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
            "Rekabet: \(me?.displayName ?? "Sen") \(record.wins) galibiyet, \(rival.displayName) \(rivalWins) galibiyet, \(record.draws) beraberlik"
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
            Text("galibiyet")
                .font(.wdCaption)
                .foregroundStyle(Color.wdInkSecondary)
        }
    }

    /// Henüz rakip yokken gösterilen davet kartı.
    private var inviteTeaserCard: some View {
        VStack(alignment: .leading, spacing: WDSpacing.sm) {
            Image(systemName: "figure.fencing")
                .font(.system(size: 36))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            Text("Rakibini davet et")
                .font(.wdTitle)
                .foregroundStyle(.white)
            Text("Yeni maç başlat, 6 haneli kodu arkadaşına gönder. Kim daha çok kelime biliyor, görelim.")
                .font(.wdSubheadline)
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WDSpacing.lg)
        .background(
            LinearGradient.wdAccentGradient,
            in: RoundedRectangle(cornerRadius: WDRadius.lg, style: .continuous)
        )
        .shadow(color: Color.wdAccent.opacity(0.3), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var matchSections: some View {
        let active = matches.filter { $0.status == .active }
        let myTurn = active.filter { isMyTurn($0) }
        let waiting = active.filter { !isMyTurn($0) }
        let pending = matches.filter { $0.status == .pending }

        if !myTurn.isEmpty {
            section("Sıra sende") {
                ForEach(myTurn) { match in
                    matchCard(match, isMyTurn: true)
                }
            }
        }

        if !waiting.isEmpty {
            section("Rakip oynuyor") {
                ForEach(waiting) { match in
                    matchCard(match, isMyTurn: false)
                }
            }
        }

        if !pending.isEmpty {
            section("Davet bekleyenler") {
                ForEach(pending) { match in
                    pendingCard(match)
                }
            }
        }

        if matches.isEmpty {
            VStack(spacing: WDSpacing.sm) {
                Image(systemName: "rectangle.stack.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.wdInkSecondary)
                Text("Henüz maç yok")
                    .font(.wdHeadline)
                    .foregroundStyle(Color.wdInk)
                Text("Aşağıdan yeni maç başlat veya arkadaşının koduyla katıl.")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WDSpacing.xl)
        }
    }

    private func section(_ title: LocalizedStringKey, @ViewBuilder rows: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: WDSpacing.sm) {
            Text(title)
                .font(.wdTitle)
                .foregroundStyle(Color.wdInk)
            rows()
        }
        .animation(.default, value: matches.count)
    }

    private func matchCard(_ match: Match, isMyTurn: Bool) -> some View {
        NavigationLink {
            MatchDetailView(match: match) {
                Task { await createNewMatch() }
            }
        } label: {
            matchCardLabel(match, isMyTurn: isMyTurn)
        }
        .buttonStyle(WDPressableButtonStyle())
    }

    private func matchCardLabel(_ match: Match, isMyTurn: Bool) -> some View {
        let stats = MatchStats(myAppleUserID: myAppleUserID())
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
                Text("Tur \(match.currentRoundIndex + 1)/\(match.totalRounds)")
                    .font(.wdCaption)
                    .foregroundStyle(Color.wdInkSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(stats.myScore(in: match)) – \(stats.opponentScore(in: match))")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.wdInk)
                if isMyTurn {
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
            if isMyTurn {
                RoundedRectangle(cornerRadius: WDRadius.lg, style: .continuous)
                    .strokeBorder(Color.wdAccent.opacity(0.5), lineWidth: 1.5)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(for: match, isMyTurn: isMyTurn))
    }

    /// Rakibin katılmasını bekleyen maç — dokununca kodu yeniden paylaşır.
    private func pendingCard(_ match: Match) -> some View {
        Button {
            reinvite = ReinviteCode(code: match.code)
        } label: {
            HStack(spacing: WDSpacing.md) {
                Image(systemName: "hourglass")
                    .font(.title3)
                    .foregroundStyle(Color.wdWarning)
                    .frame(width: 44, height: 44)
                    .background(Color.wdWarning.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rakip bekleniyor")
                        .font(.wdHeadline)
                        .foregroundStyle(Color.wdInk)
                    Text("Kod: \(match.code) · Paylaşmak için dokun")
                        .font(.wdCaption)
                        .foregroundStyle(Color.wdInkSecondary)
                }

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.wdInkSecondary)
            }
            .wdCard()
        }
        .buttonStyle(WDPressableButtonStyle())
        .accessibilityLabel("Rakip bekleniyor, kod \(match.code.map(String.init).joined(separator: " ")), paylaşmak için dokun")
    }

    private var actionBar: some View {
        HStack(spacing: WDSpacing.sm) {
            PrimaryButton(
                "Yeni Maç",
                systemImage: "plus",
                isLoading: isCreating
            ) {
                Task { await createNewMatch() }
            }
            SecondaryButton("Kodla Katıl", systemImage: "qrcode.viewfinder") {
                showJoinSheet = true
            }
        }
        .padding(.horizontal)
        .padding(.top, WDSpacing.sm)
        .padding(.bottom, WDSpacing.xs)
        .background(.ultraThinMaterial)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: WDSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.wdDanger)
            Text(message)
                .font(.wdCaption)
                .foregroundStyle(Color.wdInk)
            Spacer()
        }
        .padding(WDSpacing.md)
        .background(
            Color.wdDanger.opacity(0.1),
            in: RoundedRectangle(cornerRadius: WDRadius.md, style: .continuous)
        )
    }

    // MARK: - Helpers

    private var me: Player? {
        guard let myID = myAppleUserID() else { return players.first }
        return players.first { $0.appleUserID == myID }
    }

    private var rival: Player? {
        guard let myID = myAppleUserID() else { return nil }
        return players.first { $0.appleUserID != myID }
    }

    private var greetingTitle: String {
        if let name = me?.displayName, !name.isEmpty {
            return "Selam, \(name) 👋"
        }
        return "Selam 👋"
    }

    private var greetingSubtitle: String {
        guard rival != nil else { return "Bugün düelloya hazır mısın?" }
        let record = MatchStats(myAppleUserID: myAppleUserID()).record(for: matches)
        if record.wins > record.losses { return "Liderliği bırakma, seri devam etsin!" }
        if record.wins < record.losses { return "Rövanş zamanı — farkı kapat!" }
        return "Skorlar eşit. İpleri kim koparacak?"
    }

    private var isCreating: Bool {
        if case .creating = viewModel?.createState { return true }
        return false
    }

    private var createdBinding: Binding<Bool> {
        Binding(
            get: {
                if case .created = viewModel?.createState { return true }
                return false
            },
            set: { newValue in
                if !newValue { viewModel?.dismissCreatedSheet() }
            }
        )
    }

    private func createNewMatch() async {
        guard let host = me else { return }
        await viewModel?.createMatch(host: host, modelContext: modelContext)
    }

    private func myAppleUserID() -> String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
    }

    private func myRole(in match: Match) -> AskerRole? {
        MatchStats(myAppleUserID: myAppleUserID()).role(in: match)
    }

    private func currentRound(of match: Match) -> Round? {
        (match.rounds ?? []).first { $0.index == match.currentRoundIndex }
    }

    /// Faza göre aksiyon bende mi: kelime seçme, cevaplama veya değerlendirme.
    private func isMyTurn(_ match: Match) -> Bool {
        guard let me = myRole(in: match) else { return false }
        let flow = MatchFlow(match: match)
        switch flow.phase {
        case .picking(let asker):
            return asker == me
        case .answering:
            return flow.currentRound?.askerRole != me
        case .reviewing:
            return flow.currentRound?.askerRole == me
        case .waitingForOpponent, .finished:
            return false
        }
    }

    private func rowAccessibilityLabel(for match: Match, isMyTurn: Bool) -> String {
        let stats = MatchStats(myAppleUserID: myAppleUserID())
        let opponentName = stats.opponent(in: match)?.displayName ?? "Rakip"
        let turnNote = isMyTurn ? ", sıra sende" : ""
        return "Maç: \(opponentName) ile, tur \(match.currentRoundIndex + 1) / \(match.totalRounds), skor \(stats.myScore(in: match)) - \(stats.opponentScore(in: match))\(turnNote)"
    }

    /// Davet kabulünden sonra paylaşılan maç kaydı cihaza ulaştığında
    /// guest koltuğunu kapar; maç iki tarafta da aktifleşir.
    private func claimGuestSeats() {
        guard let myID = myAppleUserID(), let me else { return }
        var claimed = false
        for match in matches where match.status == .pending {
            let before = match.status
            MatchFlow.claimGuestSeatIfNeeded(match: match, me: me, myAppleUserID: myID)
            if match.status != before { claimed = true }
        }
        if claimed {
            try? modelContext.save()
        }
    }

    private func scheduleTurnNotifications() async {
        let stats = MatchStats(myAppleUserID: myAppleUserID())
        let active: [TurnNotifier.ActiveMatch] = matches.compactMap { match in
            guard match.status == .active else { return nil }
            guard myRole(in: match) != nil else { return nil }
            return TurnNotifier.ActiveMatch(
                code: match.code,
                isMyTurnToAnswer: isMyTurn(match),
                opponentDisplayName: stats.opponent(in: match)?.displayName ?? "Rakip"
            )
        }

        let toSchedule = TurnNotifier().notifications(for: active)
        for notification in toSchedule {
            await services.notificationScheduler.scheduleTurn(notification)
        }
        // Sıra başkasındaysa eski bildirimi temizle
        for match in active where !match.isMyTurnToAnswer {
            await services.notificationScheduler.cancel(matchCode: match.code)
        }
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Match.self, Player.self, Round.self], inMemory: true)
        .environment(AuthController())
}
