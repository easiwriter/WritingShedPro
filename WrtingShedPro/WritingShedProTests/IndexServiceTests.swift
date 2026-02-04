//
//  IndexServiceTests.swift
//  WritingShedProTests
//
//  Feature 033: Index Generation Tests
//  Created by GitHub Copilot on 04/02/2026.
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class IndexServiceTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var indexService: IndexService!
    var project: Project!
    
    override func setUpWithError() throws {
        // Create in-memory model container
        let schema = Schema([
            Project.self,
            IndexEntry.self,
            TextFile.self,
            Folder.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(modelContainer)
        
        // Create test project
        project = Project(name: "Test Project")
        modelContext.insert(project)
        try modelContext.save()
        
        // Create IndexService
        indexService = IndexService()
        indexService.configure(with: modelContext)
    }
    
    override func tearDownWithError() throws {
        indexService = nil
        modelContainer = nil
        modelContext = nil
        project = nil
    }
    
    // MARK: - FindOrCreateEntry Tests
    
    @MainActor
    func testFindOrCreateEntryCreatesNewEntry() async throws {
        let entry = indexService.findOrCreateEntry(keyword: "Dogs", project: project)
        
        XCTAssertNotNil(entry)
        XCTAssertEqual(entry?.keyword, "Dogs")
        XCTAssertNil(entry?.parentEntry)
        XCTAssertEqual(entry?.depth, 1)
    }
    
    @MainActor
    func testFindOrCreateEntryFindsExisting() async throws {
        // Create first entry
        let entry1 = indexService.findOrCreateEntry(keyword: "Cats", project: project)
        
        // Try to create with same keyword - should return existing
        let entry2 = indexService.findOrCreateEntry(keyword: "Cats", project: project)
        
        XCTAssertEqual(entry1?.id, entry2?.id)
    }
    
    @MainActor
    func testFindOrCreateEntryCaseInsensitive() async throws {
        let entry1 = indexService.findOrCreateEntry(keyword: "Animals", project: project)
        let entry2 = indexService.findOrCreateEntry(keyword: "ANIMALS", project: project)
        
        XCTAssertEqual(entry1?.id, entry2?.id)
    }
    
    @MainActor
    func testFindOrCreateEntryWithParent() async throws {
        let parent = indexService.findOrCreateEntry(keyword: "Animals", project: project)
        let child = indexService.findOrCreateEntry(keyword: "Dogs", parent: parent, project: project)
        
        XCTAssertNotNil(child)
        XCTAssertEqual(child?.parentEntry?.id, parent?.id)
        XCTAssertEqual(child?.depth, 2)
    }
    
    @MainActor
    func testFindOrCreateEntryRespectsMaxDepth() async throws {
        // Create 3-level hierarchy
        let level1 = indexService.findOrCreateEntry(keyword: "Level1", project: project)
        let level2 = indexService.findOrCreateEntry(keyword: "Level2", parent: level1, project: project)
        let level3 = indexService.findOrCreateEntry(keyword: "Level3", parent: level2, project: project)
        
        // Level 3 can't have children (max depth reached)
        XCTAssertNotNil(level3)
        XCTAssertFalse(level3!.canHaveChildren)
        
        // Trying to add child to level3 should return nil (max depth reached)
        let level4 = indexService.findOrCreateEntry(keyword: "Level4", parent: level3, project: project)
        // Should be nil because parent is at max depth and can't have children
        XCTAssertNil(level4, "Should return nil when attempting to add child to entry at max depth")
    }
    
    // MARK: - Reference Tracking Tests
    
    @MainActor
    func testAddReference() async throws {
        let entry = indexService.findOrCreateEntry(keyword: "Test", project: project)!
        let fileID = UUID()
        
        indexService.addReference(to: entry, fromFile: fileID)
        
        XCTAssertEqual(entry.referenceCount, 1)
        XCTAssertTrue(entry.referencingFileIDs.contains(fileID))
    }
    
    @MainActor
    func testRemoveReference() async throws {
        let entry = indexService.findOrCreateEntry(keyword: "Test", project: project)!
        let fileID = UUID()
        
        // Add then remove
        indexService.addReference(to: entry, fromFile: fileID)
        indexService.removeReference(from: entry, inFile: fileID, wasLastInFile: true)
        
        XCTAssertEqual(entry.referenceCount, 0)
        XCTAssertFalse(entry.referencingFileIDs.contains(fileID))
    }
    
    // MARK: - Cross-Reference Tests
    
    @MainActor
    func testSetSeeReference() async throws {
        let dogs = indexService.findOrCreateEntry(keyword: "Dogs", project: project)!
        let animals = indexService.findOrCreateEntry(keyword: "Animals", project: project)!
        
        indexService.setSeeReference(for: dogs, to: animals)
        
        XCTAssertEqual(dogs.seeEntryID, animals.id)
    }
    
    @MainActor
    func testAddSeeAlsoReference() async throws {
        let dogs = indexService.findOrCreateEntry(keyword: "Dogs", project: project)!
        let cats = indexService.findOrCreateEntry(keyword: "Cats", project: project)!
        
        indexService.addSeeAlsoReference(for: dogs, to: cats)
        
        XCTAssertTrue(dogs.seeAlsoEntryIDs.contains(cats.id))
    }
    
    // MARK: - Reparent Tests
    
    @MainActor
    func testReparentEntry() async throws {
        let dogs = indexService.findOrCreateEntry(keyword: "Dogs", project: project)!
        let animals = indexService.findOrCreateEntry(keyword: "Animals", project: project)!
        
        let success = indexService.reparentEntry(dogs, to: animals)
        
        XCTAssertTrue(success)
        XCTAssertEqual(dogs.parentEntry?.id, animals.id)
        XCTAssertEqual(dogs.depth, 2)
    }
    
    @MainActor
    func testReparentEntryFailsAtMaxDepth() async throws {
        // Create 2-level hierarchy
        let level1 = indexService.findOrCreateEntry(keyword: "Level1", project: project)!
        let level2 = indexService.findOrCreateEntry(keyword: "Level2", parent: level1, project: project)!
        let level3 = indexService.findOrCreateEntry(keyword: "Level3", parent: level2, project: project)!
        
        // Try to make level3 a parent of a new entry that has a child
        let other = indexService.findOrCreateEntry(keyword: "Other", project: project)!
        let otherChild = indexService.findOrCreateEntry(keyword: "OtherChild", parent: other, project: project)!
        
        // Trying to reparent otherChild under level3 should fail (would exceed max depth)
        let success = indexService.reparentEntry(otherChild, to: level3)
        
        XCTAssertFalse(success)
    }
    
    // MARK: - Index Generation Tests
    
    @MainActor
    func testGenerateIndexSectionsGroupedByLetter() async throws {
        _ = indexService.findOrCreateEntry(keyword: "Apple", project: project)
        _ = indexService.findOrCreateEntry(keyword: "Banana", project: project)
        _ = indexService.findOrCreateEntry(keyword: "Avocado", project: project)
        
        try modelContext.save()
        
        let sections = indexService.generateIndex(for: project)
        
        // Should have A and B sections
        XCTAssertEqual(sections.count, 2)
        
        let aSection = sections.first { $0.letter == "A" }
        XCTAssertNotNil(aSection)
        XCTAssertEqual(aSection?.entries.count, 2) // Apple, Avocado
        
        let bSection = sections.first { $0.letter == "B" }
        XCTAssertNotNil(bSection)
        XCTAssertEqual(bSection?.entries.count, 1) // Banana
    }
    
    @MainActor
    func testGenerateIndexIncludesChildren() async throws {
        let animals = indexService.findOrCreateEntry(keyword: "Animals", project: project)!
        _ = indexService.findOrCreateEntry(keyword: "Dogs", parent: animals, project: project)
        _ = indexService.findOrCreateEntry(keyword: "Cats", parent: animals, project: project)
        
        try modelContext.save()
        
        let sections = indexService.generateIndex(for: project)
        
        let aSection = sections.first { $0.letter == "A" }
        XCTAssertNotNil(aSection)
        
        let animalsEntry = aSection?.entries.first { $0.keyword == "Animals" }
        XCTAssertNotNil(animalsEntry)
        XCTAssertEqual(animalsEntry?.children.count, 2)
    }
}
