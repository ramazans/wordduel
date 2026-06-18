import SwiftUI
import SwiftData
import CoreModels
import AuthService

/// Auth durumuna göre root switch.
struct AppRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController
    @Query private var players: [Player]

    var body: some View {
        Group {
            switch authController.phase {
            case .signedIn(let appleUserID):
                // Apple ismi yalnızca ilk onayda gelir; gelmediyse (geri dönen
                // kullanıcı / reinstall) ve Keychain'de de yoksa kullanıcıyı
                // Player-XXXX'e mahkûm etmek yerine adını sor. Gerçek ad
                // belirlenince HomeView'a geçilir.
                if let me = currentPlayer(appleUserID), !Player.isRealName(me.displayName) {
                    NameEntryView(player: me)
                } else {
                    HomeView()
                }
            case .signingIn, .idle, .revoked, .error:
                OnboardingView()
            }
        }
        .task {
            await authController.bootstrap(modelContext: modelContext)
        }
    }

    private func currentPlayer(_ appleUserID: String) -> Player? {
        players.first { $0.appleUserID == appleUserID }
    }
}

#Preview {
    AppRoot()
        .environment(AuthController())
        .modelContainer(for: [Player.self, Match.self, Round.self], inMemory: true)
}
