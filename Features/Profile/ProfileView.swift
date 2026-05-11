import SwiftUI
import SwiftData
import CoreModels
import AuthService
import DesignSystem

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController
    @Query private var players: [Player]

    @State private var showSignOutConfirm = false

    var body: some View {
        Form {
            if let me = currentPlayer {
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
                            .accessibilityHidden(true)
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

            Section {
                Button("Çıkış Yap", role: .destructive) {
                    showSignOutConfirm = true
                }
            }
        }
        .navigationTitle("Profil")
        .confirmationDialog(
            "Çıkış yapmak istediğine emin misin?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Çıkış Yap", role: .destructive) {
                authController.signOut(modelContext: modelContext)
            }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Yerel oyuncu kaydın silinecek ve giriş ekranına döneceksin.")
        }
    }

    private var currentPlayer: Player? {
        guard case .signedIn(let appleUserID) = authController.phase else {
            return players.first
        }
        return players.first(where: { $0.appleUserID == appleUserID }) ?? players.first
    }
}

#Preview {
    NavigationStack { ProfileView() }
        .modelContainer(for: [Player.self], inMemory: true)
        .environment(AuthController())
}
