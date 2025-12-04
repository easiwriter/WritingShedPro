import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class FootnoteManagerTests: XCTestCase {
    
    var manager: FootnoteManager!
    var modelContext: ModelContext!
    var testVersion: Version!
    
    override func setUpWithError() throws {
        manager = FootnoteManager.shared
        
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
        try modelContext.save()
    }
    
    override func tearDownWithError() throws {
        let fetchDescriptor = FetchDescriptor<FootnoteModel>()
        if let footnotes = try? modelContext.fetch(fetchDescriptor) {
            footnotes.forEach { modelContext.delete($0) }
        }
        try? modelContext.save()
    }
    
    func testCreateFootnote() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Test footnote",
            context: modelContext
        )
        
        XCTAssertEqual(footnote.characterPosition, 0)
        XCTAssertEqual(footnote.text, "Test footnote")
    }
    
    func testGetFootnoteByID() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Footnote 1",
            context: modelContext
        )
        
        let retrieved = manager.getFootnote(id: footnote.id, context: modelContext)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.id, footnote.id)
        XCTAssertEqual(retrieved?.text, "Footnote 1")
    }
    
    func testGetFootnoteByAttachmentID() throws {
        let attachmentID = UUID()
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: attachmentID,
            text: "Footnote 1",
            context: modelContext
        )
        
        let retrieved = manager.getFootnoteByAttachment(attachmentID: attachmentID, context: modelContext)
        
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.attachmentID, attachmentID)
        XCTAssertEqual(retrieved?.text, "Footnote 1")
    }
    
    func testGetFootnoteByIDNotFound() throws {
        let nonexistentID = UUID()
        
        let retrieved = manager.getFootnote(id: nonexistentID, context: modelContext)
        
        XCTAssertNil(retrieved)
    }
    
    func testDeleteFootnote() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 5,
            attachmentID: UUID(),
            text: "To delete",
            context: modelContext
        )
        
        let footnoteID = footnote.id
        manager.deleteFootnote(footnote, context: modelContext)
        
        let retrieved = manager.getFootnote(id: footnoteID, context: modelContext)
        XCTAssertNil(retrieved)
    }
    
    func testUpdateFootnoteText() throws {
        let footnote = manager.createFootnote(
            version: testVersion,
            characterPosition: 5,
            attachmentID: UUID(),
            text: "Original",
            context: modelContext
        )
        
        manager.updateFootnoteText(footnote, newText: "Updated", context: modelContext)
        
        let updated = manager.getFootnote(id: footnote.id, context: modelContext)
        
        XCTAssertEqual(updated?.text, "Updated")
    }
    
    func testGetAllFootnotesForVersion() throws {
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Footnote 1",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Footnote 2",
            context: modelContext
        )
        
        let allFootnotes = manager.getAllFootnotes(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(allFootnotes.count, 2)
    }
    
    func testFootnoteNumbering() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        XCTAssertEqual(footnote1.number, 1)
        XCTAssertEqual(footnote2.number, 2)
        XCTAssertEqual(footnote3.number, 3)
    }
    
    func testFootnoteRenumbering() throws {
        let footnote1 = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "First",
            context: modelContext
        )
        
        let footnote2 = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Second",
            context: modelContext
        )
        
        let footnote3 = manager.createFootnote(
            version: testVersion,
            characterPosition: 20,
            attachmentID: UUID(),
            text: "Third",
            context: modelContext
        )
        
        manager.deleteFootnote(footnote2, context: modelContext)
        
        let remaining = manager.getAllFootnotes(forVersion: testVersion, context: modelContext)
        XCTAssertEqual(remaining.count, 2)
        
        let first = manager.getFootnote(id: footnote1.id, context: modelContext)
        let third = manager.getFootnote(id: footnote3.id, context: modelContext)
        
        XCTAssertEqual(first?.number, 1)
        XCTAssertEqual(third?.number, 2)
    }
    
    func testGetFootnoteCount() throws {
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 0,
            attachmentID: UUID(),
            text: "Footnote 1",
            context: modelContext
        )
        
        _ = manager.createFootnote(
            version: testVersion,
            characterPosition: 10,
            attachmentID: UUID(),
            text: "Footnote 2",
            context: modelContext
        )
        
        let count = manager.getFootnoteCount(forVersion: testVersion, context: modelContext)
        
        XCTAssertEqual(count, 2)
    }
}
