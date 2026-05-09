import SwiftUI
import SwiftData
import CoreModels

@main
struct WordDuelApp: App {
    private let container: ModelContainer

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
        }
        .modelContainer(container)
    }
}
