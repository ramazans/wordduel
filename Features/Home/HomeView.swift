import SwiftUI
import SwiftData
import CoreModels
import DesignSystem

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Match.createdAt, order: .reverse) private var matches: [Match]

    var body: some View {
        NavigationStack {
            Group {
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
            }
            .navigationTitle("Maçlar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Yeni Maç", systemImage: "plus.circle") { /* TODO */ }
                        Button("Kodla Katıl", systemImage: "rectangle.and.text.magnifyingglass") { /* TODO */ }
                        Button("Profil", systemImage: "person.crop.circle") { /* TODO */ }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
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
}

#Preview {
    HomeView()
        .modelContainer(for: [Match.self, Player.self, Round.self], inMemory: true)
}
