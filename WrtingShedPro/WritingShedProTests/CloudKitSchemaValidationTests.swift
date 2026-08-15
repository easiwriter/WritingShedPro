import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class CloudKitSchemaValidationTests: XCTestCase {
    func testProductionSchemaLoadsWithCloudKitValidation() throws {
        let schema = Schema(Write_App.modelTypes)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .automatic
        )

        _ = try ModelContainer(for: schema, configurations: [configuration])
    }
}
