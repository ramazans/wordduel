import SwiftUI
import SwiftData
import CoreModels
import AuthService

@main
struct WordDuelApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    @State private var authController = AuthController(
        storageKey: AppConstants.appleUserIDStorageKey
    )
    @State private var services = AppServices(
        cloudKitContainerID: AppConstants.cloudKitContainerID,
        cloudKitEnabled: AppConstants.cloudKitEnabled
    )

    init() {
        if AppConstants.cloudKitEnabled {
            container = SchemaContainer.makeResilientContainer()
        } else {
            do {
                container = try SchemaContainer.makeContainer(cloudKit: false)
            } catch {
                container = SchemaContainer.makeResilientContainer()
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRoot()
                .environment(authController)
                .environment(services)
                .task {
                    appDelegate.pushSink = { outcome in
                        Task { @MainActor in services.handlePushOutcome(outcome) }
                    }
                    await services.bootstrap()
                }
        }
        .modelContainer(container)
    }
}
