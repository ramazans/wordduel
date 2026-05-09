import SwiftUI
import SwiftData
import CoreModels
import DesignSystem

struct ProfileView: View {
    @Query private var players: [Player]

    var body: some View {
        NavigationStack {
            Form {
                if let me = players.first {
                    Section {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(AvatarPalette.color(for: me.avatarColor))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Text(me.displayName.prefix(1).uppercased())
                                        .font(.wdTitle)
                                        .foregroundStyle(.white)
                                )
                            VStack(alignment: .leading) {
                                Text(me.displayName)
                                    .font(.wdHeadline)
                                Text("Üyelik: \(me.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.wdCaption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Geçmiş") {
                    NavigationLink("Tüm maçlar") { HistoryView() }
                }

                Section {
                    NavigationLink("Ayarlar") { SettingsView() }
                }
            }
            .navigationTitle("Profil")
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Player.self], inMemory: true)
}
