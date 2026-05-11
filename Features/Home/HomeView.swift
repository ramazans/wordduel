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

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Maçlar")
                .toolbar { menuToolbar }
                .sheet(isPresented: createdBinding) {
                    if case .created(let code, _) = viewModel?.createState {
                        InviteView(code: code) {
                            viewModel?.dismissCreatedSheet()
                        }
                        .presentationDetents([.medium])
                    }
                }
                .sheet(isPresented: $showJoinSheet) {
                    JoinByCodeView(syncService: services.matchSyncService)
                        .presentationDetents([.medium])
                }
                .task {
                    if viewModel == nil {
                        viewModel = HomeViewModel(syncService: services.matchSyncService)
                    }
                    await scheduleTurnNotifications()
                }
                .task {
                    for await _ in services.pushUpdates {
                        await scheduleTurnNotifications()
                    }
                }
                .refreshable {
                    await scheduleTurnNotifications()
                }
        }
    }

    @ToolbarContentBuilder
    private var menuToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Yeni Maç", systemImage: "plus.circle") {
                    Task { await createNewMatch() }
                }
                Button("Kodla Katıl", systemImage: "rectangle.and.text.magnifyingglass") {
                    showJoinSheet = true
                }
                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Profil", systemImage: "person.crop.circle")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .accessibilityLabel("Menü")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if matches.isEmpty {
            ContentUnavailableView {
                Label("Henüz maç yok", systemImage: "rectangle.stack.badge.plus")
            } description: {
                Text("Yeni maç başlat veya kodla katıl.")
            } actions: {
                Button("Yeni Maç") { Task { await createNewMatch() } }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            List {
                let active = matches.filter { $0.status == .active }
                let pending = matches.filter { $0.status == .pending }
                if !active.isEmpty {
                    Section("Aktif") {
                        ForEach(active) { match in matchRow(match, isMyTurn: isMyTurn(match)) }
                    }
                }
                if !pending.isEmpty {
                    Section("Davetler") {
                        ForEach(pending) { match in matchRow(match, isMyTurn: false) }
                    }
                }
            }
            .animation(.default, value: matches.count)
        }

        if case .creating = viewModel?.createState {
            ProgressView("Maç oluşturuluyor…")
                .padding()
                .accessibilityLabel("Maç oluşturuluyor")
        }
        if case .error(let message) = viewModel?.createState {
            Text(message)
                .font(.wdCaption)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func matchRow(_ match: Match, isMyTurn: Bool) -> some View {
        HStack {
            if isMyTurn {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading) {
                Text(match.code)
                    .font(.wdMonoSmall)
                Text("\(match.hostScore) — \(match.guestScore)")
                    .font(.wdCaption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Tur \(match.currentRoundIndex + 1)/\(match.totalRounds)")
                .font(.wdCaption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(for: match, isMyTurn: isMyTurn))
    }

    // MARK: - Helpers

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
        guard let host = players.first else { return }
        await viewModel?.createMatch(host: host, modelContext: modelContext)
    }

    private func myAppleUserID() -> String? {
        if case .signedIn(let id) = authController.phase { return id }
        return nil
    }

    private func myRole(in match: Match) -> AskerRole? {
        guard let myID = myAppleUserID() else { return nil }
        if match.host?.appleUserID == myID { return .host }
        if match.guest?.appleUserID == myID { return .guest }
        return nil
    }

    private func currentRound(of match: Match) -> Round? {
        match.rounds?.first { $0.index == match.currentRoundIndex }
    }

    private func isMyTurn(_ match: Match) -> Bool {
        guard let me = myRole(in: match), let round = currentRound(of: match) else { return false }
        return round.askerRole != me && round.judgement == .pendingReview
    }

    private func rowAccessibilityLabel(for match: Match, isMyTurn: Bool) -> String {
        let turnNote = isMyTurn ? ", sıra sende" : ""
        return "Maç \(match.code), tur \(match.currentRoundIndex + 1) / \(match.totalRounds), skor \(match.hostScore) - \(match.guestScore)\(turnNote)"
    }

    private func scheduleTurnNotifications() async {
        let active: [TurnNotifier.ActiveMatch] = matches.compactMap { match in
            guard match.status == .active else { return nil }
            guard let me = myRole(in: match) else { return nil }
            let opponent = me == .host ? match.guest : match.host
            return TurnNotifier.ActiveMatch(
                code: match.code,
                isMyTurnToAnswer: isMyTurn(match),
                opponentDisplayName: opponent?.displayName ?? "Rakip"
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
