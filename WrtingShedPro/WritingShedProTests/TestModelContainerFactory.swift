import SwiftData
@testable import Writing_Shed_Pro

@MainActor
enum TestModelContainerFactory {
    static func make() throws -> ModelContainer {
        let schema = Schema(Write_App.modelTypes)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}