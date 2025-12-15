//
//  VersionNotesTests.swift
//  Writing Shed ProTests
//
//  Created on 13 December 2025.
//  Tests for Version notes feature
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class VersionNotesTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var project: Project!
    var textFile: TextFile!
    var version: Version!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        modelContext = ModelContext(modelContainer)
        
        // Create test project and text file
        project = Project(name: "Test Project", type: .blank, creationDate: Date())
        modelContext.insert(project)
        
        textFile = TextFile()
        textFile.name = "Test File"
        textFile.createdDate = Date()
        textFile.modifiedDate = Date()
        // TextFile() creates a first version automatically, clear it for clean tests
        textFile.versions = []
        modelContext.insert(textFile)
        
        version = Version()
        version.versionNumber = 1
        version.content = "Test content"
        version.textFile = textFile
        version.createdDate = Date()
        modelContext.insert(version)
        
        try modelContext.save()
    }
    
    override func tearDown() async throws {
        project = nil
        textFile = nil
        version = nil
        modelContainer = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Notes Tests
    
    func testVersionNotes_DefaultIsNil() throws {
        // New versions should have nil notes by default
        let newVersion = Version()
        XCTAssertNil(newVersion.notes)
    }
    
    func testVersionNotes_CanBeSet() throws {
        // Test setting notes on a version
        let testNotes = "This is a test note"
        version.notes = testNotes
        
        XCTAssertEqual(version.notes, testNotes)
    }
    
    func testVersionNotes_Persistence() throws {
        // Test that notes persist after save
        let testNotes = "Persistent note content"
        version.notes = testNotes
        try modelContext.save()
        
        // Verify notes are still there
        XCTAssertEqual(version.notes, testNotes)
    }
    
    func testVersionNotes_CanBeCleared() throws {
        // Test clearing notes
        version.notes = "Some content"
        XCTAssertNotNil(version.notes)
        
        version.notes = nil
        XCTAssertNil(version.notes)
        
        try modelContext.save()
        XCTAssertNil(version.notes)
    }
    
    func testVersionNotes_EmptyString() throws {
        // Test with empty string
        version.notes = ""
        XCTAssertNotNil(version.notes)
        XCTAssertEqual(version.notes, "")
        
        try modelContext.save()
        XCTAssertEqual(version.notes, "")
    }
    
    // MARK: - Multiple Version Tests
    
    func testVersionNotes_IndependentBetweenVersions() throws {
        // Create two versions with different notes
        let version1 = version!
        version1.notes = "Notes for version 1"
        
        let version2 = Version()
        version2.versionNumber = 2
        version2.content = "Version 2 content"
        version2.textFile = textFile
        version2.createdDate = Date()
        version2.notes = "Notes for version 2"
        modelContext.insert(version2)
        
        try modelContext.save()
        
        // Verify each version has its own notes
        XCTAssertEqual(version1.notes, "Notes for version 1")
        XCTAssertEqual(version2.notes, "Notes for version 2")
        XCTAssertNotEqual(version1.notes, version2.notes)
    }
    
    func testVersionNotes_OneWithNotesOneWithout() throws {
        // Test one version with notes, one without
        let version1 = version!
        version1.notes = "Only version 1 has notes"
        
        let version2 = Version()
        version2.versionNumber = 2
        version2.content = "Version 2 content"
        version2.textFile = textFile
        version2.createdDate = Date()
        version2.notes = nil
        modelContext.insert(version2)
        
        try modelContext.save()
        
        XCTAssertNotNil(version1.notes)
        XCTAssertNil(version2.notes)
    }
    
    // MARK: - Content Tests
    
    func testVersionNotes_MultilineContent() throws {
        // Test multiline notes
        let multilineNotes = """
        First line of notes
        Second line of notes
        Third line of notes
        """
        
        version.notes = multilineNotes
        try modelContext.save()
        
        XCTAssertEqual(version.notes, multilineNotes)
        XCTAssertTrue(version.notes?.contains("\n") ?? false)
    }
    
    func testVersionNotes_SpecialCharacters() throws {
        // Test notes with special characters
        let specialNotes = "Notes with special chars: !@#$%^&*() €£¥ 中文 العربية 😀📝"
        
        version.notes = specialNotes
        try modelContext.save()
        
        XCTAssertEqual(version.notes, specialNotes)
    }
    
    func testVersionNotes_LongContent() throws {
        // Test with very long notes
        let longNotes = String(repeating: "This is a long note. ", count: 100)
        
        version.notes = longNotes
        try modelContext.save()
        
        XCTAssertEqual(version.notes, longNotes)
        XCTAssertTrue((version.notes?.count ?? 0) > 1000)
    }
    
    func testVersionNotes_EmojiContent() throws {
        // Test notes with emoji
        let emojiNotes = "📝 Important reminder 🔔\n✅ Done\n❌ Not done"
        
        version.notes = emojiNotes
        try modelContext.save()
        
        XCTAssertEqual(version.notes, emojiNotes)
    }
    
    // MARK: - Update Tests
    
    func testVersionNotes_CanBeUpdated() throws {
        // Test updating existing notes
        version.notes = "Original notes"
        try modelContext.save()
        
        XCTAssertEqual(version.notes, "Original notes")
        
        version.notes = "Updated notes"
        try modelContext.save()
        
        XCTAssertEqual(version.notes, "Updated notes")
    }
    
    func testVersionNotes_MultipleUpdates() throws {
        // Test multiple sequential updates
        let updates = [
            "First update",
            "Second update",
            "Third update",
            "Final update"
        ]
        
        for (index, update) in updates.enumerated() {
            version.notes = update
            try modelContext.save()
            
            XCTAssertEqual(version.notes, update, "Failed at update \(index + 1)")
        }
    }
    
    // MARK: - Relationship Tests
    
    func testVersionNotes_DoesNotAffectTextFile() throws {
        // Verify notes don't affect parent text file
        let originalName = textFile.name
        let originalContent = version.content
        
        version.notes = "Adding notes should not affect text file"
        try modelContext.save()
        
        XCTAssertEqual(textFile.name, originalName)
        XCTAssertEqual(version.content, originalContent)
    }
    
    func testVersionNotes_PreservedAfterTextFileUpdate() throws {
        // Verify notes persist when text file is updated
        version.notes = "These notes should persist"
        try modelContext.save()
        
        // Update text file
        textFile.name = "Updated File Name"
        textFile.modifiedDate = Date()
        try modelContext.save()
        
        // Notes should still be there
        XCTAssertEqual(version.notes, "These notes should persist")
    }
    
    func testVersionNotes_PreservedAfterContentUpdate() throws {
        // Verify notes persist when version content changes
        version.notes = "Important notes"
        version.content = "Original content"
        try modelContext.save()
        
        // Update version content
        version.content = "New content"
        try modelContext.save()
        
        // Notes should still be there
        XCTAssertEqual(version.notes, "Important notes")
    }
    
    // MARK: - Query Tests
    
    func testVersionNotes_QueryVersionsWithNotes() throws {
        // Create versions with and without notes (don't use the setUp version to keep count clear)
        // Clear the setUp version first
        version.notes = nil
        
        let version1 = Version()
        version1.versionNumber = 10
        version1.content = "Content 1"
        version1.textFile = textFile
        version1.createdDate = Date()
        version1.notes = "Version 1 notes"
        modelContext.insert(version1)
        
        let version2 = Version()
        version2.versionNumber = 11
        version2.content = "Content 2"
        version2.textFile = textFile
        version2.createdDate = Date()
        version2.notes = nil
        modelContext.insert(version2)
        
        let version3 = Version()
        version3.versionNumber = 12
        version3.content = "Content 3"
        version3.textFile = textFile
        version3.createdDate = Date()
        version3.notes = "Version 3 notes"
        modelContext.insert(version3)
        
        try modelContext.save()
        
        // Query all versions
        let descriptor = FetchDescriptor<Version>()
        let allVersions = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(allVersions.count, 4, "Should have 4 versions (1 from setUp + 3 created)")
        
        // Count versions with notes (version1 and version3)
        let versionsWithNotes = allVersions.filter { $0.notes != nil && !$0.notes!.isEmpty }
        XCTAssertEqual(versionsWithNotes.count, 2, "Should have 2 versions with notes")
        
        // Count versions without notes (setUp version and version2)
        let versionsWithoutNotes = allVersions.filter { $0.notes == nil || $0.notes!.isEmpty }
        XCTAssertEqual(versionsWithoutNotes.count, 2, "Should have 2 versions without notes")
    }
    
    // MARK: - Import Tests
    
    func testVersionNotes_ImportFromLegacyData() throws {
        // Simulate importing notes from legacy WS_Version_Entity
        let legacyNotesString = "Legacy notes from Writing Shed v1"
        
        // In the actual import, this would come from decoding WS_Version_Entity.notes
        version.notes = legacyNotesString
        try modelContext.save()
        
        XCTAssertEqual(version.notes, legacyNotesString)
    }
    
    func testVersionNotes_ImportEmptyNotes() throws {
        // Test importing empty notes from legacy data
        version.notes = ""
        try modelContext.save()
        
        XCTAssertNotNil(version.notes)
        XCTAssertEqual(version.notes, "")
    }
    
    func testVersionNotes_ImportNilNotes() throws {
        // Test importing nil notes from legacy data
        version.notes = nil
        try modelContext.save()
        
        XCTAssertNil(version.notes)
    }
    
    // MARK: - Edge Cases
    
    func testVersionNotes_VeryLongNotes() throws {
        // Test with extremely long notes (10,000 characters)
        let veryLongNotes = String(repeating: "A", count: 10000)
        
        version.notes = veryLongNotes
        try modelContext.save()
        
        XCTAssertEqual(version.notes?.count, 10000)
    }
    
    func testVersionNotes_OnlyWhitespace() throws {
        // Test notes with only whitespace
        let whitespaceNotes = "   \n\n\t\t   "
        
        version.notes = whitespaceNotes
        try modelContext.save()
        
        XCTAssertEqual(version.notes, whitespaceNotes)
    }
    
    func testVersionNotes_UnicodeContent() throws {
        // Test various Unicode content
        let unicodeNotes = "Unicode: \u{1F4DD} \u{00A9} \u{2665} \u{03B1}\u{03B2}\u{03B3}"
        
        version.notes = unicodeNotes
        try modelContext.save()
        
        XCTAssertEqual(version.notes, unicodeNotes)
    }
}
