//
//  ReferenceModelsTests.swift
//  WritingShedProTests
//
//  Unit tests for Feature 029: Back Matter Reference System Models
//  Tests NoteEntry, GlossaryEntry, CitationEntry, and IndexEntry
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ReferenceModelsTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self,
            NoteEntry.self, GlossaryEntry.self, CitationEntry.self, IndexEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
        
        testProject = Project(name: "Test Project", type: .prose)
        modelContext.insert(testProject)
    }
    
    override func tearDown() {
        testProject = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - NoteEntry Tests
    
    func testNoteEntryInitialization() {
        let note = NoteEntry(
            project: testProject,
            content: "This is a test note",
            isEndnote: false,
            displayNumber: 1,
            title: "Test Note"
        )
        modelContext.insert(note)
        
        XCTAssertNotNil(note.id)
        XCTAssertEqual(note.project?.id, testProject.id)
        XCTAssertEqual(note.content, "This is a test note")
        XCTAssertFalse(note.isEndnote)
        XCTAssertEqual(note.displayNumber, 1)
        XCTAssertEqual(note.title, "Test Note")
        XCTAssertEqual(note.referenceCount, 0)
        XCTAssertNotNil(note.createdAt)
        XCTAssertNotNil(note.modifiedAt)
    }
    
    func testNoteEntryEndnote() {
        let endnote = NoteEntry(
            project: testProject,
            content: "Endnote content",
            isEndnote: true,
            displayNumber: 1
        )
        modelContext.insert(endnote)
        
        XCTAssertTrue(endnote.isEndnote)
        XCTAssertEqual(endnote.inlineMarker, "[1]")
    }
    
    func testNoteEntryGeneralNote() {
        let note = NoteEntry(
            project: testProject,
            content: "General note content",
            isEndnote: false,
            displayNumber: 2
        )
        modelContext.insert(note)
        
        XCTAssertFalse(note.isEndnote)
        XCTAssertEqual(note.inlineMarker, "[Note 2]")
    }
    
    func testNoteEntryUpdateContent() {
        let note = NoteEntry(
            project: testProject,
            content: "Original content",
            isEndnote: false,
            displayNumber: 1
        )
        modelContext.insert(note)
        
        let originalModifiedAt = note.modifiedAt
        
        // Small delay to ensure time difference
        Thread.sleep(forTimeInterval: 0.01)
        
        note.updateContent("Updated content")
        
        XCTAssertEqual(note.content, "Updated content")
        XCTAssertGreaterThan(note.modifiedAt, originalModifiedAt)
    }
    
    func testNoteEntryReferenceCount() {
        let note = NoteEntry(
            project: testProject,
            content: "Test note",
            isEndnote: false,
            displayNumber: 1
        )
        modelContext.insert(note)
        
        XCTAssertEqual(note.referenceCount, 0)
        XCTAssertTrue(note.isOrphaned)
        
        note.incrementReferenceCount()
        XCTAssertEqual(note.referenceCount, 1)
        XCTAssertFalse(note.isOrphaned)
        
        note.incrementReferenceCount()
        XCTAssertEqual(note.referenceCount, 2)
        
        note.decrementReferenceCount()
        XCTAssertEqual(note.referenceCount, 1)
        
        note.decrementReferenceCount()
        XCTAssertEqual(note.referenceCount, 0)
        XCTAssertTrue(note.isOrphaned)
        
        // Should not go below 0
        note.decrementReferenceCount()
        XCTAssertEqual(note.referenceCount, 0)
    }
    
    func testNoteEntryPlainTextMarker() {
        let endnote = NoteEntry(
            project: testProject,
            content: "Content",
            isEndnote: true,
            displayNumber: 5
        )
        
        let generalNote = NoteEntry(
            project: testProject,
            content: "Content",
            isEndnote: false,
            displayNumber: 3
        )
        
        XCTAssertEqual(endnote.plainTextMarker, "(see Note 5)")
        XCTAssertEqual(generalNote.plainTextMarker, "(see Note 3)")
    }
    
    func testNoteEntryComparable() {
        let note1 = NoteEntry(project: testProject, content: "A", displayNumber: 1)
        let note2 = NoteEntry(project: testProject, content: "B", displayNumber: 2)
        let note3 = NoteEntry(project: testProject, content: "C", displayNumber: 3)
        
        let sorted = [note3, note1, note2].sorted()
        
        XCTAssertEqual(sorted[0].displayNumber, 1)
        XCTAssertEqual(sorted[1].displayNumber, 2)
        XCTAssertEqual(sorted[2].displayNumber, 3)
    }
    
    // MARK: - GlossaryEntry Tests
    
    func testGlossaryEntryInitialization() {
        let entry = GlossaryEntry(
            project: testProject,
            term: "Protagonist",
            definition: "The main character of a story"
        )
        modelContext.insert(entry)
        
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.project?.id, testProject.id)
        XCTAssertEqual(entry.term, "Protagonist")
        XCTAssertEqual(entry.definition, "The main character of a story")
        XCTAssertEqual(entry.referenceCount, 0)
        XCTAssertNotNil(entry.createdAt)
        XCTAssertNotNil(entry.modifiedAt)
    }
    
    func testGlossaryEntryInlineMarker() {
        let entry = GlossaryEntry(
            project: testProject,
            term: "Antagonist",
            definition: "The opposing force"
        )
        
        XCTAssertEqual(entry.inlineMarker, "Antagonist")
    }
    
    func testGlossaryEntryPlainTextMarker() {
        let entry = GlossaryEntry(
            project: testProject,
            term: "Metaphor",
            definition: "A figure of speech"
        )
        
        XCTAssertEqual(entry.plainTextMarker, "Metaphor (see Glossary)")
    }
    
    func testGlossaryEntryUpdateDefinition() {
        let entry = GlossaryEntry(
            project: testProject,
            term: "Term",
            definition: "Original definition"
        )
        modelContext.insert(entry)
        
        let originalModifiedAt = entry.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        
        entry.updateDefinition("Updated definition")
        
        XCTAssertEqual(entry.definition, "Updated definition")
        XCTAssertGreaterThan(entry.modifiedAt, originalModifiedAt)
    }
    
    func testGlossaryEntryReferenceCount() {
        let entry = GlossaryEntry(
            project: testProject,
            term: "Test",
            definition: "Definition"
        )
        modelContext.insert(entry)
        
        XCTAssertTrue(entry.isOrphaned)
        
        entry.incrementReferenceCount()
        XCTAssertFalse(entry.isOrphaned)
        XCTAssertEqual(entry.referenceCount, 1)
        
        entry.decrementReferenceCount()
        XCTAssertTrue(entry.isOrphaned)
    }
    
    func testGlossaryEntryComparable() {
        let entry1 = GlossaryEntry(project: testProject, term: "Apple", definition: "A fruit")
        let entry2 = GlossaryEntry(project: testProject, term: "Zebra", definition: "An animal")
        let entry3 = GlossaryEntry(project: testProject, term: "Banana", definition: "A fruit")
        
        let sorted = [entry2, entry1, entry3].sorted()
        
        XCTAssertEqual(sorted[0].term, "Apple")
        XCTAssertEqual(sorted[1].term, "Banana")
        XCTAssertEqual(sorted[2].term, "Zebra")
    }
    
    // MARK: - CitationEntry Tests
    
    func testCitationEntryInitialization() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Smith, John", "Doe, Jane"],
            year: 2024,
            title: "Test Article",
            source: "Journal of Testing",
            url: "https://example.com",
            doi: "10.1234/test",
            sourceType: .article
        )
        modelContext.insert(citation)
        
        XCTAssertNotNil(citation.id)
        XCTAssertEqual(citation.project?.id, testProject.id)
        XCTAssertEqual(citation.authors, ["Smith, John", "Doe, Jane"])
        XCTAssertEqual(citation.year, 2024)
        XCTAssertEqual(citation.title, "Test Article")
        XCTAssertEqual(citation.source, "Journal of Testing")
        XCTAssertEqual(citation.url, "https://example.com")
        XCTAssertEqual(citation.doi, "10.1234/test")
        XCTAssertEqual(citation.sourceType, .article)
        XCTAssertEqual(citation.referenceCount, 0)
    }
    
    func testCitationEntryPrimaryAuthorLastName() {
        // Test "Last, First" format
        let citation1 = CitationEntry(
            project: testProject,
            authors: ["Smith, John"],
            year: 2024,
            title: "Test"
        )
        XCTAssertEqual(citation1.primaryAuthorLastName, "Smith")
        
        // Test "First Last" format
        let citation2 = CitationEntry(
            project: testProject,
            authors: ["John Smith"],
            year: 2024,
            title: "Test"
        )
        XCTAssertEqual(citation2.primaryAuthorLastName, "Smith")
        
        // Test empty authors
        let citation3 = CitationEntry(
            project: testProject,
            authors: [],
            year: 2024,
            title: "Test"
        )
        XCTAssertEqual(citation3.primaryAuthorLastName, "Unknown")
    }
    
    func testCitationEntryInlineMarkerSingleAuthor() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Smith, John"],
            year: 2024,
            title: "Test"
        )
        
        XCTAssertEqual(citation.inlineMarker, "[Smith, 2024]")
    }
    
    func testCitationEntryInlineMarkerTwoAuthors() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Smith, John", "Doe, Jane"],
            year: 2024,
            title: "Test"
        )
        
        XCTAssertEqual(citation.inlineMarker, "[Smith & Doe, 2024]")
    }
    
    func testCitationEntryInlineMarkerThreeOrMoreAuthors() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Smith, John", "Doe, Jane", "Brown, Bob"],
            year: 2024,
            title: "Test"
        )
        
        XCTAssertEqual(citation.inlineMarker, "[Smith et al., 2024]")
    }
    
    func testCitationEntryPlainTextMarker() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Smith, John"],
            year: 2024,
            title: "Test"
        )
        
        XCTAssertEqual(citation.plainTextMarker, "(Smith, 2024)")
    }
    
    func testCitationEntrySourceTypes() {
        XCTAssertEqual(CitationEntry.SourceType.article.displayName, NSLocalizedString("citation.type.article", comment: "Article"))
        XCTAssertEqual(CitationEntry.SourceType.book.displayName, NSLocalizedString("citation.type.book", comment: "Book"))
        XCTAssertEqual(CitationEntry.SourceType.website.displayName, NSLocalizedString("citation.type.website", comment: "Website"))
    }
    
    func testCitationEntryReferenceCount() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Test"],
            year: 2024,
            title: "Test"
        )
        modelContext.insert(citation)
        
        XCTAssertTrue(citation.isOrphaned)
        
        citation.incrementReferenceCount()
        XCTAssertFalse(citation.isOrphaned)
        
        citation.decrementReferenceCount()
        XCTAssertTrue(citation.isOrphaned)
    }
    
    func testCitationEntryComparable() {
        let citation1 = CitationEntry(project: testProject, authors: ["Zebra"], year: 2020, title: "A")
        let citation2 = CitationEntry(project: testProject, authors: ["Apple"], year: 2024, title: "B")
        let citation3 = CitationEntry(project: testProject, authors: ["Apple"], year: 2020, title: "C")
        
        let sorted = [citation1, citation2, citation3].sorted()
        
        // Sorted by author, then year
        XCTAssertEqual(sorted[0].title, "C") // Apple, 2020
        XCTAssertEqual(sorted[1].title, "B") // Apple, 2024
        XCTAssertEqual(sorted[2].title, "A") // Zebra, 2020
    }
    
    // MARK: - IndexEntry Tests
    
    func testIndexEntryInitialization() {
        let entry = IndexEntry(
            project: testProject,
            keyword: "Testing"
        )
        modelContext.insert(entry)
        
        XCTAssertNotNil(entry.id)
        XCTAssertEqual(entry.project?.id, testProject.id)
        XCTAssertEqual(entry.keyword, "Testing")
        XCTAssertNil(entry.parentEntry)
        XCTAssertEqual(entry.referenceCount, 0)
        XCTAssertTrue(entry.isTopLevel)
        XCTAssertNotNil(entry.createdAt)
        XCTAssertNotNil(entry.modifiedAt)
    }
    
    func testIndexEntryWithParent() {
        let parent = IndexEntry(project: testProject, keyword: "Animals")
        let child = IndexEntry(project: testProject, keyword: "Dogs", parentEntry: parent)
        
        modelContext.insert(parent)
        modelContext.insert(child)
        
        XCTAssertTrue(parent.isTopLevel)
        XCTAssertFalse(child.isTopLevel)
        XCTAssertEqual(child.parentEntry?.id, parent.id)
    }
    
    func testIndexEntryFullPath() {
        let grandparent = IndexEntry(project: testProject, keyword: "Animals")
        let parent = IndexEntry(project: testProject, keyword: "Dogs", parentEntry: grandparent)
        let child = IndexEntry(project: testProject, keyword: "Breeds", parentEntry: parent)
        
        modelContext.insert(grandparent)
        modelContext.insert(parent)
        modelContext.insert(child)
        
        XCTAssertEqual(grandparent.fullPath, "Animals")
        XCTAssertEqual(parent.fullPath, "Animals > Dogs")
        XCTAssertEqual(child.fullPath, "Animals > Dogs > Breeds")
    }
    
    func testIndexEntryInlineMarkerIsEmpty() {
        let entry = IndexEntry(project: testProject, keyword: "Test")
        
        // Index markers are invisible
        XCTAssertEqual(entry.inlineMarker, "")
        XCTAssertEqual(entry.plainTextMarker, "")
    }
    
    func testIndexEntryUpdateKeyword() {
        let entry = IndexEntry(project: testProject, keyword: "Original")
        modelContext.insert(entry)
        
        let originalModifiedAt = entry.modifiedAt
        Thread.sleep(forTimeInterval: 0.01)
        
        entry.updateKeyword("Updated")
        
        XCTAssertEqual(entry.keyword, "Updated")
        XCTAssertGreaterThan(entry.modifiedAt, originalModifiedAt)
    }
    
    func testIndexEntryPageNumbers() {
        let entry = IndexEntry(project: testProject, keyword: "Test")
        modelContext.insert(entry)
        
        // Initially empty
        XCTAssertTrue(entry.pageNumbers.isEmpty)
        
        // Set page numbers
        entry.pageNumbers = [1, 3, 5, 6, 7, 12]
        
        XCTAssertEqual(entry.pageNumbers, [1, 3, 5, 6, 7, 12])
    }
    
    func testIndexEntryFormattedPageNumbers() {
        let entry = IndexEntry(project: testProject, keyword: "Test")
        modelContext.insert(entry)
        
        // Test range formatting
        entry.pageNumbers = [1, 3, 5, 6, 7, 12]
        XCTAssertEqual(entry.formattedPageNumbers, "1, 3, 5-7, 12")
        
        // Test single page
        entry.pageNumbers = [5]
        XCTAssertEqual(entry.formattedPageNumbers, "5")
        
        // Test consecutive range
        entry.pageNumbers = [1, 2, 3, 4, 5]
        XCTAssertEqual(entry.formattedPageNumbers, "1-5")
        
        // Test empty
        entry.pageNumbers = []
        XCTAssertEqual(entry.formattedPageNumbers, "")
    }
    
    func testIndexEntryReferenceCount() {
        let entry = IndexEntry(project: testProject, keyword: "Test")
        modelContext.insert(entry)
        
        XCTAssertTrue(entry.isOrphaned)
        
        entry.incrementReferenceCount()
        XCTAssertFalse(entry.isOrphaned)
        
        entry.decrementReferenceCount()
        XCTAssertTrue(entry.isOrphaned)
    }
    
    func testIndexEntryComparable() {
        let entry1 = IndexEntry(project: testProject, keyword: "Zebra")
        let entry2 = IndexEntry(project: testProject, keyword: "Apple")
        let entry3 = IndexEntry(project: testProject, keyword: "Banana")
        
        let sorted = [entry1, entry2, entry3].sorted()
        
        XCTAssertEqual(sorted[0].keyword, "Apple")
        XCTAssertEqual(sorted[1].keyword, "Banana")
        XCTAssertEqual(sorted[2].keyword, "Zebra")
    }
    
    // MARK: - ReferenceType Tests
    
    func testReferenceTypeMarkerFormats() {
        XCTAssertEqual(ReferenceType.note.markerFormat, "[Note %d]")
        XCTAssertEqual(ReferenceType.endnote.markerFormat, "[%d]")
        XCTAssertEqual(ReferenceType.reference.markerFormat, "[%@, %@]")
        XCTAssertEqual(ReferenceType.glossary.markerFormat, "%@")
        XCTAssertEqual(ReferenceType.index.markerFormat, "")
        XCTAssertEqual(ReferenceType.figure.markerFormat, "[Fig %d]")
        XCTAssertEqual(ReferenceType.table.markerFormat, "[Table %d]")
    }
    
    func testReferenceTypePlainTextFormats() {
        XCTAssertEqual(ReferenceType.note.plainTextFormat, "(see Note %d)")
        XCTAssertEqual(ReferenceType.endnote.plainTextFormat, "(see Note %d)")
        XCTAssertEqual(ReferenceType.reference.plainTextFormat, "(%@, %@)")
        XCTAssertEqual(ReferenceType.glossary.plainTextFormat, "%@ (see Glossary)")
        XCTAssertEqual(ReferenceType.index.plainTextFormat, "")
    }
}
