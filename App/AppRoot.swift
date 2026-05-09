import SwiftUI
import SwiftData
import CoreModels

/// Auth durumuna göre root switch.
/// Faz 2'de gerçek auth state takibi eklenecek; şu an her zaman onboarding.
struct AppRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var players: [Player]

    var body: some View {
        Group {
            if players.first != nil {
                HomeView()
            } else {
                OnboardingView()
            }
        }
    }
}

#Preview {
    AppRoot()
        .modelContainer(for: [Player.self, Match.self, Round.self], inMemory: true)
}
