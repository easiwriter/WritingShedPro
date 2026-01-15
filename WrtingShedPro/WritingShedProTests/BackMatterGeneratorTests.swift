//
//  BackMatterGeneratorTests.swift
//  WritingShedProTests
//
//  Unit tests for Feature 029: BackMatterGenerator
//  Tests back matter section generation for manuscript export
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class BackMatterGeneratorTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    var generator: BackMatterGenerator!
    
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
        
        generator = BackMatterGenerator(context: modelContext, project: testProject)
    }
    
    override func tearDown() {
        generator = nil
        testProject = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Notes Section Tests
    
    func testGenerateNotesSectionWithNoNotes() {
        let result = generator.generateNotesSection()
        XCTAssertNil(result)
    }
    
    func testGenerateNotesSectionWithEndnotes() {
        // Create test endnotes
        let note1 = NoteEntry(project: testProject, content: "First endnote content", isEndnote: true, displayNumber: 1)
        let note2 = NoteEntry(project: testProject, content: "Second endnote content", isEndnote: true, displayNumber: 2)
        
        modelContext.insert(note1)
        modelContext.insert(note2)
        try? modelContext.save()
        
        let result = generator.generateNotesSection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("[1]"))
        XCTAssertTrue(text.contains("[2]"))
        XCTAssertTrue(text.contains("First endnote content"))
        XCTAssertTrue(text.contains("Second endnote content"))
    }
    
    func testGenerateNotesSectionWithGeneralNotes() {
        // Create test general notes
        let note = NoteEntry(project: testProject, content: "General note content", isEndnote: false, displayNumber: 1, title: "Important Note")
        
        modelContext.insert(note)
        try? modelContext.save()
        
        let result = generator.generateNotesSection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("[Note 1]"))
        XCTAssertTrue(text.contains("Important Note"))
        XCTAssertTrue(text.contains("General note content"))
    }
    
    func testGenerateNotesSectionMixedTypes() {
        // Create both endnotes and general notes
        let endnote = NoteEntry(project: testProject, content: "Endnote", isEndnote: true, displayNumber: 1)
        let generalNote = NoteEntry(project: testProject, content: "General", isEndnote: false, displayNumber: 1)
        
        modelContext.insert(endnote)
        modelContext.insert(generalNote)
        try? modelContext.save()
        
        let result = generator.generateNotesSection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("[1]"))
        XCTAssertTrue(text.contains("[Note 1]"))
    }
    
    // MARK: - Glossary Section Tests
    
    func testGenerateGlossarySectionWithNoEntries() {
        let result = generator.generateGlossarySection()
        XCTAssertNil(result)
    }
    
    func testGenerateGlossarySectionWithEntries() {
        // Create test glossary entries
        let entry1 = GlossaryEntry(project: testProject, term: "Protagonist", definition: "The main character")
        let entry2 = GlossaryEntry(project: testProject, term: "Antagonist", definition: "The opposing force")
        
        modelContext.insert(entry1)
        modelContext.insert(entry2)
        try? modelContext.save()
        
        let result = generator.generateGlossarySection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("Protagonist"))
        XCTAssertTrue(text.contains("The main character"))
        XCTAssertTrue(text.contains("Antagonist"))
        XCTAssertTrue(text.contains("The opposing force"))
    }
    
    func testGenerateGlossarySectionAlphabeticalGrouping() {
        // Create entries starting with different letters
        let entryA = GlossaryEntry(project: testProject, term: "Apple", definition: "A fruit")
        let entryB = GlossaryEntry(project: testProject, term: "Banana", definition: "Another fruit")
        let entryZ = GlossaryEntry(project: testProject, term: "Zebra", definition: "An animal")
        
        modelContext.insert(entryA)
        modelContext.insert(entryB)
        modelContext.insert(entryZ)
        try? modelContext.save()
        
        let result = generator.generateGlossarySection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        
        // Check letter headings appear
        XCTAssertTrue(text.contains("A\n"))
        XCTAssertTrue(text.contains("B\n"))
        XCTAssertTrue(text.contains("Z\n"))
        
        // Check order (A should come before B, B before Z)
        let aIndex = text.range(of: "Apple")?.lowerBound
        let bIndex = text.range(of: "Banana")?.lowerBound
        let zIndex = text.range(of: "Zebra")?.lowerBound
        
        XCTAssertNotNil(aIndex)
        XCTAssertNotNil(bIndex)
        XCTAssertNotNil(zIndex)
        XCTAssertLessThan(aIndex!, bIndex!)
        XCTAssertLessThan(bIndex!, zIndex!)
    }
    
    // MARK: - Bibliography Section Tests
    
    func testGenerateBibliographySectionWithNoCitations() {
        let result = generator.generateBibliographySection()
        XCTAssertNil(result)
    }
    
    func testGenerateBibliographySectionWithCitations() {
        // Create test citations
        let citation1 = CitationEntry(
            project: testProject,
            authors: ["Smith, John"],
            year: 2024,
            title: "Test Article",
            source: "Test Journal"
        )
        let citation2 = CitationEntry(
            project: testProject,
            authors: ["Doe, Jane", "Brown, Bob"],
            year: 2023,
            title: "Another Article",
            source: "Another Journal"
        )
        
        modelContext.insert(citation1)
        modelContext.insert(citation2)
        try? modelContext.save()
        
        let result = generator.generateBibliographySection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("Smith"))
        XCTAssertTrue(text.contains("2024"))
        XCTAssertTrue(text.contains("Test Article"))
        XCTAssertTrue(text.contains("Doe"))
        XCTAssertTrue(text.contains("Another Article"))
    }
    
    func testGenerateBibliographySectionWithURL() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Author"],
            year: 2024,
            title: "Web Article",
            url: "https://example.com/article"
        )
        
        modelContext.insert(citation)
        try? modelContext.save()
        
        let result = generator.generateBibliographySection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("https://example.com/article"))
    }
    
    func testGenerateBibliographySectionWithDOI() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["Author"],
            year: 2024,
            title: "Journal Article",
            doi: "10.1234/test.2024"
        )
        
        modelContext.insert(citation)
        try? modelContext.save()
        
        let result = generator.generateBibliographySection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("https://doi.org/10.1234/test.2024"))
    }
    
    func testGenerateBibliographySectionSortedByAuthor() {
        let citationZ = CitationEntry(project: testProject, authors: ["Zebra"], year: 2020, title: "Z Article")
        let citationA = CitationEntry(project: testProject, authors: ["Apple"], year: 2024, title: "A Article")
        
        modelContext.insert(citationZ)
        modelContext.insert(citationA)
        try? modelContext.save()
        
        let result = generator.generateBibliographySection()
        
        XCTAssertNotNil(result)
        let text = result!.string
        
        // Apple should come before Zebra
        let appleIndex = text.range(of: "Apple")?.lowerBound
        let zebraIndex = text.range(of: "Zebra")?.lowerBound
        
        XCTAssertNotNil(appleIndex)
        XCTAssertNotNil(zebraIndex)
        XCTAssertLessThan(appleIndex!, zebraIndex!)
    }
    
    // MARK: - Index Section Tests
    
    func testGenerateIndexSectionWithNoEntries() {
        let result = generator.generateIndexSection(pageMap: [:])
        XCTAssertNil(result)
    }
    
    func testGenerateIndexSectionWithEntries() {
        let entry1 = IndexEntry(project: testProject, keyword: "Testing")
        let entry2 = IndexEntry(project: testProject, keyword: "Development")
        
        modelContext.insert(entry1)
        modelContext.insert(entry2)
        try? modelContext.save()
        
        let pageMap: [UUID: [Int]] = [
            entry1.id: [1, 5, 10],
            entry2.id: [3, 4]
        ]
        
        let result = generator.generateIndexSection(pageMap: pageMap)
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("Testing"))
        XCTAssertTrue(text.contains("Development"))
    }
    
    func testGenerateIndexSectionWithPageNumbers() {
        let entry = IndexEntry(project: testProject, keyword: "Swift")
        
        modelContext.insert(entry)
        try? modelContext.save()
        
        let pageMap: [UUID: [Int]] = [
            entry.id: [1, 3, 5, 6, 7, 12]
        ]
        
        let result = generator.generateIndexSection(pageMap: pageMap)
        
        XCTAssertNotNil(result)
        let text = result!.string
        XCTAssertTrue(text.contains("Swift"))
        // Should format as ranges: "1, 3, 5–7, 12"
        XCTAssertTrue(text.contains("1") && text.contains("3") && text.contains("12"))
    }
    
    func testGenerateIndexSectionAlphabeticalGrouping() {
        let entryA = IndexEntry(project: testProject, keyword: "Apple")
        let entryB = IndexEntry(project: testProject, keyword: "Banana")
        let entryZ = IndexEntry(project: testProject, keyword: "Zebra")
        
        modelContext.insert(entryA)
        modelContext.insert(entryB)
        modelContext.insert(entryZ)
        try? modelContext.save()
        
        let result = generator.generateIndexSection(pageMap: [:])
        
        XCTAssertNotNil(result)
        let text = result!.string
        
        // Check alphabetical order
        let appleIndex = text.range(of: "Apple")?.lowerBound
        let bananaIndex = text.range(of: "Banana")?.lowerBound
        let zebraIndex = text.range(of: "Zebra")?.lowerBound
        
        XCTAssertNotNil(appleIndex)
        XCTAssertNotNil(bananaIndex)
        XCTAssertNotNil(zebraIndex)
        XCTAssertLessThan(appleIndex!, bananaIndex!)
        XCTAssertLessThan(bananaIndex!, zebraIndex!)
    }
    
    // MARK: - Combined Back Matter Tests
    
    func testGenerateBackMatterAllSections() {
        // Create entries for all sections
        let note = NoteEntry(project: testProject, content: "Note content", isEndnote: true, displayNumber: 1)
        let glossary = GlossaryEntry(project: testProject, term: "Term", definition: "Definition")
        let citation = CitationEntry(project: testProject, authors: ["Author"], year: 2024, title: "Title")
        let index = IndexEntry(project: testProject, keyword: "Keyword")
        
        modelContext.insert(note)
        modelContext.insert(glossary)
        modelContext.insert(citation)
        modelContext.insert(index)
        try? modelContext.save()
        
        let result = generator.generateBackMatter(
            includeNotes: true,
            includeGlossary: true,
            includeBibliography: true,
            includeIndex: true,
            pageMap: [index.id: [1, 2, 3]]
        )
        
        let text = result.string
        XCTAssertTrue(text.contains("Note content"))
        XCTAssertTrue(text.contains("Term"))
        XCTAssertTrue(text.contains("Definition"))
        XCTAssertTrue(text.contains("Author"))
        XCTAssertTrue(text.contains("Keyword"))
    }
    
    func testGenerateBackMatterSelectiveSections() {
        // Create entries for all sections
        let note = NoteEntry(project: testProject, content: "Note content", isEndnote: true, displayNumber: 1)
        let glossary = GlossaryEntry(project: testProject, term: "Term", definition: "Definition")
        
        modelContext.insert(note)
        modelContext.insert(glossary)
        try? modelContext.save()
        
        // Only include notes
        let result = generator.generateBackMatter(
            includeNotes: true,
            includeGlossary: false,
            includeBibliography: false,
            includeIndex: false
        )
        
        let text = result.string
        XCTAssertTrue(text.contains("Note content"))
        XCTAssertFalse(text.contains("Term"))
    }
    
    func testGenerateBackMatterEmpty() {
        // No entries at all
        let result = generator.generateBackMatter(
            includeNotes: true,
            includeGlossary: true,
            includeBibliography: true,
            includeIndex: true
        )
        
        // Should return empty attributed string
        XCTAssertEqual(result.length, 0)
    }
    
    // MARK: - Plain Text Back Matter Tests
    
    func testGeneratePlainTextBackMatterNotes() {
        let note = NoteEntry(project: testProject, content: "Plain text note", isEndnote: true, displayNumber: 1)
        
        modelContext.insert(note)
        // Establish bidirectional relationship
        if testProject.noteEntries == nil {
            testProject.noteEntries = []
        }
        testProject.noteEntries?.append(note)
        try? modelContext.save()
        
        let result = generator.generatePlainTextBackMatter(
            includeNotes: true,
            includeGlossary: false,
            includeBibliography: false
        )
        
        XCTAssertTrue(result.contains("[1]"))
        XCTAssertTrue(result.contains("Plain text note"))
        // Check for heading (either localized "Notes" or the key "backMatter.notes.heading")
        XCTAssertTrue(result.contains("Notes") || result.contains("backMatter.notes.heading"))
    }
    
    func testGeneratePlainTextBackMatterGlossary() {
        let entry = GlossaryEntry(project: testProject, term: "PlainTerm", definition: "Plain definition")
        
        modelContext.insert(entry)
        // Establish bidirectional relationship
        if testProject.glossaryEntries == nil {
            testProject.glossaryEntries = []
        }
        testProject.glossaryEntries?.append(entry)
        try? modelContext.save()
        
        let result = generator.generatePlainTextBackMatter(
            includeNotes: false,
            includeGlossary: true,
            includeBibliography: false
        )
        
        XCTAssertTrue(result.contains("PlainTerm"))
        XCTAssertTrue(result.contains("Plain definition"))
        // Check for heading (either localized "Glossary" or the key "backMatter.glossary.heading")
        XCTAssertTrue(result.contains("Glossary") || result.contains("backMatter.glossary.heading"))
    }
    
    func testGeneratePlainTextBackMatterBibliography() {
        let citation = CitationEntry(
            project: testProject,
            authors: ["PlainAuthor"],
            year: 2024,
            title: "Plain Title"
        )
        
        modelContext.insert(citation)
        // Establish bidirectional relationship
        if testProject.citationEntries == nil {
            testProject.citationEntries = []
        }
        testProject.citationEntries?.append(citation)
        try? modelContext.save()
        
        let result = generator.generatePlainTextBackMatter(
            includeNotes: false,
            includeGlossary: false,
            includeBibliography: true
        )
        
        XCTAssertTrue(result.contains("PlainAuthor"))
        XCTAssertTrue(result.contains("2024"))
        XCTAssertTrue(result.contains("Plain Title"))
        // Check for heading (either localized "Bibliography" or the key "backMatter.bibliography.heading")
        XCTAssertTrue(result.contains("Bibliography") || result.contains("backMatter.bibliography.heading"))
    }
    
    func testGeneratePlainTextBackMatterEmpty() {
        let result = generator.generatePlainTextBackMatter(
            includeNotes: true,
            includeGlossary: true,
            includeBibliography: true
        )
        
        XCTAssertTrue(result.isEmpty)
    }
}
