import Foundation
import SwiftData

public enum SchemaContainer {
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
}
