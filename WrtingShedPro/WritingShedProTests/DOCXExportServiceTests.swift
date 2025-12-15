import XCTest
import SwiftData
import UniformTypeIdentifiers
@testable import Writing_Shed_Pro

final class DOCXExportServiceTests: XCTestCase {
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var exportService: DOCXExportService!
    
    override func setUp() async throws {
        let schema = Schema([TextFile.self, Project.self, Version.self, Folder.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(modelContainer)
        exportService = DOCXExportService(modelContext: modelContext)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        exportService = nil
    }
    
    func testExportToDOCX_WithValidContent() throws {
        let attributedString = NSAttributedString(string: "Hello, World!\nThis is a test.")
        
        let data = try exportService.exportToDOCX(attributedString, filename: "Test.docx")
        XCTAssertFalse(data.isEmpty)
        
        // Verify it's a valid ZIP file by checking the first bytes (PK header)
        let zipHeader = data.prefix(4)
        let expectedHeader = Data([0x50, 0x4B, 0x03, 0x04]) // "PK\x03\x04"
        XCTAssertEqual(zipHeader, expectedHeader, "Data should be a valid ZIP file")
    }
    
    func testExportToDOCX_WithNoContent_ThrowsError() {
        let attributedString = NSAttributedString(string: "")
        
        XCTAssertThrowsError(try exportService.exportToDOCX(attributedString, filename: "Empty.docx")) { error in
            XCTAssertEqual(error as? DOCXExportError, .noContent)
        }
    }
    
    func testExportMultipleToDOCX_WithValidFiles() throws {
        let attr1 = NSAttributedString(string: "Content 1")
        let attr2 = NSAttributedString(string: "Content 2")
        
        let data = try exportService.exportMultipleToDOCX([attr1, attr2], filename: "Combined.docx")
        
        XCTAssertFalse(data.isEmpty)
        
        // Verify it's a valid ZIP file
        let zipHeader = data.prefix(4)
        let expectedHeader = Data([0x50, 0x4B, 0x03, 0x04])
        XCTAssertEqual(zipHeader, expectedHeader, "Data should be a valid ZIP file")
    }
}
