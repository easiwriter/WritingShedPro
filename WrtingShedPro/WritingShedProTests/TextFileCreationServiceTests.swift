import XCTest
@testable import Writing_Shed_Pro

@MainActor
final class TextFileCreationServiceTests: XCTestCase {
    func testReadOnlyAccessRejectsEntireBatch() {
        let authorization = FileCreationAuthorization(
            canModifyContent: { false },
            canCreateFile: { _, _ in true }
        )

        XCTAssertThrowsError(
            try TextFileCreationService.validateCreationAccess(
                projectType: .prose,
                existingFileCount: 0,
                requestedFileCount: 3,
                authorization: authorization
            )
        ) { error in
            guard case TextFileCopyError.readOnlyAccess = error else {
                return XCTFail("Expected read-only access error, received \(error)")
            }
        }
    }

    func testFreeTierRejectsBatchThatWouldExceedLimit() {
        var checkedExistingCount: Int?
        let authorization = FileCreationAuthorization(
            canModifyContent: { true },
            canCreateFile: { _, existingCount in
                checkedExistingCount = existingCount
                return existingCount < 1
            }
        )

        XCTAssertThrowsError(
            try TextFileCreationService.validateCreationAccess(
                projectType: .fiction,
                existingFileCount: 0,
                requestedFileCount: 2,
                authorization: authorization
            )
        ) { error in
            guard case TextFileCopyError.fileLimit(.fiction) = error else {
                return XCTFail("Expected fiction file-limit error, received \(error)")
            }
        }
        XCTAssertEqual(checkedExistingCount, 1)
    }

    func testFreeTierAllowsSingleFileInEmptyProject() throws {
        let authorization = FileCreationAuthorization(
            canModifyContent: { true },
            canCreateFile: { _, existingCount in existingCount < 1 }
        )

        try TextFileCreationService.validateCreationAccess(
            projectType: .poetry,
            existingFileCount: 0,
            requestedFileCount: 1,
            authorization: authorization
        )
    }

    func testUnlimitedAccessValidatesFinalInsertionForWholeBatch() throws {
        var checkedExistingCount: Int?
        let authorization = FileCreationAuthorization(
            canModifyContent: { true },
            canCreateFile: { _, existingCount in
                checkedExistingCount = existingCount
                return true
            }
        )

        try TextFileCreationService.validateCreationAccess(
            projectType: .drama,
            existingFileCount: 4,
            requestedFileCount: 3,
            authorization: authorization
        )

        XCTAssertEqual(checkedExistingCount, 6)
    }
}
