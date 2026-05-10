import SwiftUI
import SwiftData
import CoreModels
import AuthService

/// Auth durumuna göre root switch.
struct AppRoot: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthController.self) private var authController

    var body: some View {
        Group {
            switch authController.phase {
            case .signedIn:
                HomeView()
            case .signingIn, .idle, .revoked, .error:
                OnboardingView()
            }
        }
        .task {
            await authController.bootstrap(modelContext: modelContext)
        }
    }
}

#Preview {
    AppRoot()
        .environment(AuthController())
        .modelContainer(for: [Player.self, Match.self, Round.self], inMemory: true)
}
