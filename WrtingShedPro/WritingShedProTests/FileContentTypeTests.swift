//
//  FileContentTypeTests.swift
//  WritingShedProTests
//
//  Tests for FileContentType enum and TextFile content type property
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class FileContentTypeTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUpWithError() throws {
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        modelContainer = nil
    }
    
    // MARK: - FileContentType Enum Tests
    
    func testContentTypeCases() {
        XCTAssertEqual(FileContentType.allCases.count, 2, "Should have exactly 2 content types")
        XCTAssertTrue(FileContentType.allCases.contains(.richText))
        XCTAssertTrue(FileContentType.allCases.contains(.markdown))
    }
    
    func testContentTypeRawValues() {
        XCTAssertEqual(FileContentType.richText.rawValue, "richText")
        XCTAssertEqual(FileContentType.markdown.rawValue, "markdown")
    }
    
    func testContentTypeLocalizedNames() {
        // Names should be non-empty localized strings
        XCTAssertFalse(FileContentType.richText.localizedName.isEmpty)
        XCTAssertFalse(FileContentType.markdown.localizedName.isEmpty)
    }
    
    func testContentTypeSystemImages() {
        XCTAssertFalse(FileContentType.richText.systemImage.isEmpty)
        XCTAssertFalse(FileContentType.markdown.systemImage.isEmpty)
    }
    
    func testContentTypeDescriptions() {
        XCTAssertFalse(FileContentType.richText.description.isEmpty)
        XCTAssertFalse(FileContentType.markdown.description.isEmpty)
    }
    
    // MARK: - TextFile Content Type Tests
    
    func testNewFileDefaultsToRichText() {
        let folder = Folder(name: "Test")
        modelContext.insert(folder)
        
        let file = TextFile(name: "Test", initialContent: "", parentFolder: folder)
        modelContext.insert(file)
        
        XCTAssertEqual(file.contentType, .richText, "New file should default to richText")
        XCTAssertFalse(file.isMarkdown, "New file should not be markdown")
    }
    
    func testSetContentTypeToMarkdown() {
        let folder = Folder(name: "Test")
        modelContext.insert(folder)
        
        let file = TextFile(name: "Test", initialContent: "", parentFolder: folder)
        modelContext.insert(file)
        
        file.contentType = .markdown
        
        XCTAssertEqual(file.contentType, .markdown)
        XCTAssertTrue(file.isMarkdown)
    }
    
    func testSetContentTypeToRichText() {
        let folder = Folder(name: "Test")
        modelContext.insert(folder)
        
        let file = TextFile(name: "Test", initialContent: "", parentFolder: folder)
        modelContext.insert(file)
        
        file.contentType = .markdown
        file.contentType = .richText
        
        XCTAssertEqual(file.contentType, .richText)
        XCTAssertFalse(file.isMarkdown)
    }
    
    func testContentTypeRawPersistence() {
        let folder = Folder(name: "Test")
        modelContext.insert(folder)
        
        let file = TextFile(name: "Test", initialContent: "", parentFolder: folder)
        modelContext.insert(file)
        
        file.contentType = .markdown
        
        XCTAssertEqual(file.contentTypeRaw, "markdown", "Raw value should be stored")
    }
    
    func testContentTypeFromInvalidRawDefaultsToRichText() {
        let folder = Folder(name: "Test")
        modelContext.insert(folder)
        
        let file = TextFile(name: "Test", initialContent: "", parentFolder: folder)
        modelContext.insert(file)
        
        // Directly set an invalid raw value
        file.contentTypeRaw = "invalidType"
        
        XCTAssertEqual(file.contentType, .richText, "Invalid raw should default to richText")
    }
    
    func testIsMarkdownConvenienceProperty() {
        let folder = Folder(name: "Test")
        modelContext.insert(folder)
        
        let file = TextFile(name: "Test", initialContent: "", parentFolder: folder)
        modelContext.insert(file)
        
        XCTAssertFalse(file.isMarkdown)
        
        file.contentType = .markdown
        XCTAssertTrue(file.isMarkdown)
        
        file.contentType = .richText
        XCTAssertFalse(file.isMarkdown)
    }
}
