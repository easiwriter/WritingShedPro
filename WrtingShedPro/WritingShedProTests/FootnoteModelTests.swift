import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class FootnoteModelTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testVersion: Version!
    
    override func setUpWithError() throws {
        let schema = Schema([
            FootnoteModel.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        modelContext = ModelContext(container)
        
        testVersion = Version(content: "Test content")
        modelContext.insert(testVersion)
    }
    
    override func tearDownWithError() throws {
        modelContext = nil
        testVersion = nil
    }
    
    func testFootnoteInitialization() throws {
        let footnote = FootnoteModel(
            version: testVersion,
            characterPosition: 10,
            text: "This is a test footnote",
            number: 1
        )
        
        XCTAssertNotNil(footnote.id)
        XCTAssertEqual(footnote.version?.id, testVersion.id)
        XCTAssertEqual(footnote.characterPosition, 10)
        XCTAssertEqual(footnote.text, "This is a test footnote")
        XCTAssertEqual(footnote.number, 1)
        XCTAssertNotNil(footnote.createdAt)
        XCTAssertNotNil(footnote.modifiedAt)
    }
    
    func testFootnoteWithDefaultValues() throws {
        let footnote = FootnoteModel(
            version: testVersion,
            characterPosition: 0,
            text: "Footnote",
            number: 1
        )
        
        XCTAssertNotNil(footnote.id)
        XCTAssertNotNil(footnote.attachmentID)
        XCTAssertNotNil(footnote.createdAt)
        XCTAssertNotNil(footnote.modifiedAt)
    }
    
    func testFootnoteUpdateText() throws {
        let footnote = FootnoteModel(
            version: testVersion,
            characterPosition: 5,
            text: "Original text",
            number: 1
        )
        
        footnote.updateText("Updated text")
        
        XCTAssertEqual(footnote.text, "Updated text")
    }
    
    func testFootnoteUpdateNumber() throws {
        let footnote = FootnoteModel(
            version: testVersion,
            characterPosition: 5,
            text: "Text",
            number: 1
        )
        
        footnote.updateNumber(2)
        
        XCTAssertEqual(footnote.number, 2)
    }
    
    func testFootnoteUpdatePosition() throws {
        let footnote = FootnoteModel(
            version: testVersion,
            characterPosition: 5,
            text: "Text",
            number: 1
        )
        
        footnote.updatePosition(20)
        
        XCTAssertEqual(footnote.characterPosition, 20)
    }
    
    func testFootnoteModifiedAtUpdates() throws {
        let footnote = FootnoteModel(
            version: testVersion,
            characterPosition: 5,
            text: "Original",
            number: 1
        )
        
        let originalModifiedAt = footnote.modifiedAt
        
        Thread.sleep(forTimeInterval: 0.01)
        
        footnote.updateText("Updated")
        
        XCTAssertGreaterThan(footnote.modifiedAt, originalModifiedAt)
    }
    
    func testMultipleFootnotesComparable() throws {
        let footnote1 = FootnoteModel(
            version: testVersion,
            characterPosition: 5,
            text: "First",
            number: 1
        )
        
        let footnote2 = FootnoteModel(
            version: testVersion,
            characterPosition: 20,
            text: "Second",
            number: 2
        )
        
        let footnote3 = FootnoteModel(
            version: testVersion,
            characterPosition: 10,
            text: "Third",
            number: 3
        )
        
        let sorted = [footnote2, footnote3, footnote1].sorted()
        
        XCTAssertEqual(sorted[0].characterPosition, 5)
        XCTAssertEqual(sorted[1].characterPosition, 10)
        XCTAssertEqual(sorted[2].characterPosition, 20)
    }
}
