import SwiftUI
import SwiftData
import CoreModels
import CloudKitService
import DesignSystem

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppServices.self) private var services
    @Query(sort: \Match.createdAt, order: .reverse) private var matches: [Match]
    @Query private var players: [Player]
    @State private var viewModel: HomeViewModel?
    @State private var showJoinSheet = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Maçlar")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Yeni Maç", systemImage: "plus.circle") {
                                Task { await createNewMatch() }
                            }
                            Button("Kodla Katıl", systemImage: "rectangle.and.text.magnifyingglass") {
                                showJoinSheet = true
                            }
                            Button("Profil", systemImage: "person.crop.circle") { /* TODO */ }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: createdBinding) {
                    if case .created(let code, _) = viewModel?.createState {
                        InviteView(code: code) {
                            viewModel?.dismissCreatedSheet()
                        }
                    }
                }
                .sheet(isPresented: $showJoinSheet) {
                    JoinByCodeView(syncService: services.matchSyncService)
                }
                .task {
                    if viewModel == nil {
                        viewModel = HomeViewModel(syncService: services.matchSyncService)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if matches.isEmpty {
            ContentUnavailableView(
                "Henüz maç yok",
                systemImage: "rectangle.stack.badge.plus",
                description: Text("Yeni maç başlat veya kodla katıl.")
            )
        } else {
            List {
                Section("Aktif") {
                    ForEach(matches.filter { $0.status == .active }) { match in
                        matchRow(match)
                    }
                }
                Section("Davetler") {
                    ForEach(matches.filter { $0.status == .pending }) { match in
                        matchRow(match)
                    }
                }
            }
        }

        if case .creating = viewModel?.createState {
            ProgressView("Maç oluşturuluyor…")
                .padding()
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
    private func matchRow(_ match: Match) -> some View {
        HStack {
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
        guard let host = players.first else { return }
        await viewModel?.createMatch(host: host, modelContext: modelContext)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Match.self, Player.self, Round.self], inMemory: true)
}
