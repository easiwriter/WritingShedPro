import XCTest
@testable import Writing_Shed_Pro

final class NameValidatorTests: XCTestCase {
    
    func testValidProjectNameSucceeds() throws {
        // Valid project names should not throw
        XCTAssertNoThrow(try NameValidator.validateProjectName("My Project"))
        XCTAssertNoThrow(try NameValidator.validateProjectName("a"))
    }
    
    func testEmptyProjectNameThrows() {
        XCTAssertThrowsError(try NameValidator.validateProjectName("")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(entity: "Project"))
        }
    }
    
    func testWhitespaceOnlyProjectNameThrows() {
        XCTAssertThrowsError(try NameValidator.validateProjectName("   ")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(entity: "Project"))
        }
    }
    
    func testValidFileNameSucceeds() throws {
        XCTAssertNoThrow(try NameValidator.validateFileName("chapter1.txt"))
        XCTAssertNoThrow(try NameValidator.validateFileName("notes"))
    }
    
    func testEmptyFileNameThrows() {
        XCTAssertThrowsError(try NameValidator.validateFileName("")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(entity: "File"))
        }
    }
    
    func testValidFolderNameSucceeds() throws {
        XCTAssertNoThrow(try NameValidator.validateFolderName("My Folder"))
        XCTAssertNoThrow(try NameValidator.validateFolderName("Draft"))
    }
    
    func testEmptyFolderNameThrows() {
        XCTAssertThrowsError(try NameValidator.validateFolderName("")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName(entity: "Folder"))
        }
    }
}
