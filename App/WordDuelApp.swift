import SwiftUI
import SwiftData
import CoreModels
import AuthService

@main
struct WordDuelApp: App {
    private let container: ModelContainer
    @State private var authController = AuthController(
        storageKey: AppConstants.appleUserIDStorageKey
    )
    @State private var services = AppServices(
        cloudKitContainerID: AppConstants.cloudKitContainerID
    )

    init() {
        do {
            container = try SchemaContainer.makeContainer(cloudKit: true)
        } catch {
            fatalError("ModelContainer kurulamadı: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(authController)
                .environment(services)
        }
        .modelContainer(container)
    }
}
