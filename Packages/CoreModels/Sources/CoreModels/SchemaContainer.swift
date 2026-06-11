import Foundation
import SwiftData
import OSLog

public enum SchemaContainer {
    private static let logger = Logger(subsystem: "club.kadro.wordduel", category: "SchemaContainer")

    public static let allModels: [any PersistentModel.Type] = [
        Player.self,
        Match.self,
        Round.self,
        WordEntry.self,
        ScoreEvent.self
    ]

    public static func makeContainer(
        cloudKit: Bool = true,
        inMemory: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(allModels)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .automatic : .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// CloudKit'i dener, başarısızsa local-only ile devam eder.
    /// Simülatörde iCloud signed-in değilse veya container Apple Developer'da
    /// yaratılmamışsa (`.automatic` yüklenemediğinde) UI yine çalışır.
    public static func makeResilientContainer(inMemory: Bool = false) -> ModelContainer {
        do {
            return try makeContainer(cloudKit: true, inMemory: inMemory)
        } catch {
            logger.warning("CloudKit container failed (\(String(describing: error))) — falling back to local-only.")
        }
        do {
            return try makeContainer(cloudKit: false, inMemory: inMemory)
        } catch {
            logger.error("Local-only container also failed (\(String(describing: error))) — falling back to in-memory.")
        }
        // Son çare: in-memory (data kalıcı olmaz ama uygulama açılır)
        do {
            return try makeContainer(cloudKit: false, inMemory: true)
        } catch {
            fatalError("ModelContainer kurulamadı (in-memory bile başarısız): \(error)")
        }
    }
}
