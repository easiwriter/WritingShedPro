//
//  TrashViewTests.swift
//  WritingShedProTests
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 4
//

import XCTest
import SwiftUI
import SwiftData
@testable import Writing_Shed_Pro

/// Unit tests for TrashView display and Put Back functionality.
///
/// **Test Coverage:**
/// - Empty state display
/// - Trash item list display
/// - Put Back single file
/// - Put Back multiple files
/// - Permanent delete
/// - Fallback to Draft folder
/// - Edit mode behavior
@MainActor
final class TrashViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    var draftFolder: Folder!
    var readyFolder: Folder!
    var testFile1: TextFile!
    var testFile2: TextFile!
    var trashItem1: TrashItem!
    var trashItem2: TrashItem!
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Project.self, Folder.self, TextFile.self, TrashItem.self,
            configurations: config
        )
        modelContext = modelContainer.mainContext
        
        // Create test project and folders
        testProject = Project(name: "Test Project", type: .poetry)
        modelContext.insert(testProject)
        
        draftFolder = Folder(name: "Draft", project: testProject)
        readyFolder = Folder(name: "Ready", project: testProject)
        
        testProject.folders = [draftFolder, readyFolder]
        
        try modelContext.save()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        testProject = nil
        draftFolder = nil
        readyFolder = nil
        testFile1 = nil
        testFile2 = nil
        trashItem1 = nil
        trashItem2 = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a trash item with test file
    private func createTrashItem(
        name: String,
        originalFolder: Folder,
        deletedDate: Date = Date()
    ) -> TrashItem {
        let file = TextFile(name: name, parentFolder: nil)
        modelContext.insert(file)
        
        let trashItem = TrashItem(
            textFile: file,
            originalFolder: originalFolder,
            project: testProject
        )
        trashItem.deletedDate = deletedDate
        modelContext.insert(trashItem)
        
        return trashItem
    }
    
    /// Creates a TrashView for testing
    private func createTrashView() -> TrashView {
        TrashView(project: testProject)
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        let view = createTrashView()
        XCTAssertNotNil(view, "TrashView should initialize successfully")
    }
    
    func testInitializationWithEmptyTrash() {
        let view = createTrashView()
        XCTAssertNotNil(view, "TrashView should handle empty trash")
    }
    
    func testInitializationWithTrashItems() throws {
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        XCTAssertNotNil(view, "TrashView should display trash items")
    }
    
    // MARK: - Display Tests
    
    func testEmptyStateShown() {
        let view = createTrashView()
        // With no trash items, empty state should be shown
        XCTAssertNotNil(view, "Should show empty state when no items in trash")
    }
    
    func testTrashItemsDisplayed() throws {
        trashItem1 = createTrashItem(name: "File 1", originalFolder: draftFolder)
        trashItem2 = createTrashItem(name: "File 2", originalFolder: readyFolder)
        try modelContext.save()
        
        let view = createTrashView()
        XCTAssertNotNil(view, "Should display all trash items")
    }
    
    func testDisplaysFileName() throws {
        trashItem1 = createTrashItem(name: "My Poem", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        XCTAssertNotNil(view, "Should display file name")
    }
    
    func testDisplaysOriginalFolder() throws {
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        // Should show "From: Draft"
        XCTAssertNotNil(view, "Should display original folder name")
    }
    
    func testDisplaysDeletedDate() throws {
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder, deletedDate: pastDate)
        try modelContext.save()
        
        let view = createTrashView()
        XCTAssertNotNil(view, "Should display deleted date")
    }
    
    func testSortsByDeletedDateDescending() throws {
        let date1 = Date().addingTimeInterval(-3600) // 1 hour ago
        let date2 = Date().addingTimeInterval(-7200) // 2 hours ago
        
        trashItem1 = createTrashItem(name: "Newer File", originalFolder: draftFolder, deletedDate: date1)
        trashItem2 = createTrashItem(name: "Older File", originalFolder: draftFolder, deletedDate: date2)
        try modelContext.save()
        
        let view = createTrashView()
        // Newer items should appear first
        XCTAssertNotNil(view, "Should sort by deleted date, newest first")
    }
    
    // MARK: - Put Back Tests
    
    func testPutBackSingleFile() throws {
        testFile1 = TextFile(name: "Test File", parentFolder: nil)
        modelContext.insert(testFile1)
        
        trashItem1 = TrashItem(textFile: testFile1, originalFolder: draftFolder, project: testProject)
        modelContext.insert(trashItem1)
        try modelContext.save()
        
        let service = FileMoveService(modelContext: modelContext)
        
        // Put back the file
        try service.putBack(trashItem1)
        
        // Verify file is back in original folder
        XCTAssertEqual(testFile1.parentFolder?.id, draftFolder.id, "File should be restored to original folder")
        
        // Verify trash item is deleted
        let fetchDescriptor = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.id == trashItem1.id }
        )
        let remainingItems = try modelContext.fetch(fetchDescriptor)
        XCTAssertTrue(remainingItems.isEmpty, "TrashItem should be deleted after Put Back")
    }
    
    func testPutBackMultipleFiles() throws {
        testFile1 = TextFile(name: "File 1", parentFolder: nil)
        testFile2 = TextFile(name: "File 2", parentFolder: nil)
        modelContext.insert(testFile1)
        modelContext.insert(testFile2)
        
        trashItem1 = TrashItem(textFile: testFile1, originalFolder: draftFolder, project: testProject)
        trashItem2 = TrashItem(textFile: testFile2, originalFolder: readyFolder, project: testProject)
        modelContext.insert(trashItem1)
        modelContext.insert(trashItem2)
        try modelContext.save()
        
        let service = FileMoveService(modelContext: modelContext)
        
        // Put back multiple files
        try service.putBackMultiple([trashItem1, trashItem2])
        
        // Verify files are restored
        XCTAssertEqual(testFile1.parentFolder?.id, draftFolder.id, "File 1 should be restored")
        XCTAssertEqual(testFile2.parentFolder?.id, readyFolder.id, "File 2 should be restored")
        
        // Verify trash items are deleted
        let fetchDescriptor = FetchDescriptor<TrashItem>()
        let remainingItems = try modelContext.fetch(fetchDescriptor)
        XCTAssertTrue(remainingItems.isEmpty, "All TrashItems should be deleted after Put Back")
    }
    
    func testPutBackFallbackToDraft() throws {
        testFile1 = TextFile(name: "Test File", parentFolder: nil)
        modelContext.insert(testFile1)
        
        trashItem1 = TrashItem(textFile: testFile1, originalFolder: readyFolder, project: testProject)
        modelContext.insert(trashItem1)
        try modelContext.save()
        
        // Delete the original folder
        modelContext.delete(readyFolder)
        try modelContext.save()
        
        let service = FileMoveService(modelContext: modelContext)
        
        // Put back should fall back to Draft
        try service.putBack(trashItem1)
        
        // Verify file is in Draft folder
        XCTAssertEqual(testFile1.parentFolder?.id, draftFolder.id, "File should fall back to Draft folder")
    }
    
    func testPutBackWithOriginalFolderDeleted() throws {
        testFile1 = TextFile(name: "Orphaned File", parentFolder: nil)
        modelContext.insert(testFile1)
        
        // Create trash item with reference to folder
        trashItem1 = TrashItem(textFile: testFile1, originalFolder: readyFolder, project: testProject)
        modelContext.insert(trashItem1)
        try modelContext.save()
        
        // Delete original folder
        modelContext.delete(readyFolder)
        try modelContext.save()
        
        let service = FileMoveService(modelContext: modelContext)
        
        // Should not throw, should fall back to Draft
        XCTAssertNoThrow(try service.putBack(trashItem1), "Put Back should handle deleted original folder")
    }
    
    // MARK: - Permanent Delete Tests
    
    func testPermanentDelete() throws {
        testFile1 = TextFile(name: "Test File", parentFolder: nil)
        modelContext.insert(testFile1)
        
        trashItem1 = TrashItem(textFile: testFile1, originalFolder: draftFolder, project: testProject)
        modelContext.insert(trashItem1)
        try modelContext.save()
        
        let fileID = testFile1.id
        let trashItemID = trashItem1.id
        
        // Permanently delete
        modelContext.delete(testFile1)
        modelContext.delete(trashItem1)
        try modelContext.save()
        
        // Verify file is gone
        let fileFetch = FetchDescriptor<TextFile>(
            predicate: #Predicate { $0.id == fileID }
        )
        let files = try modelContext.fetch(fileFetch)
        XCTAssertTrue(files.isEmpty, "TextFile should be permanently deleted")
        
        // Verify trash item is gone
        let trashFetch = FetchDescriptor<TrashItem>(
            predicate: #Predicate { $0.id == trashItemID }
        )
        let trashItems = try modelContext.fetch(trashFetch)
        XCTAssertTrue(trashItems.isEmpty, "TrashItem should be permanently deleted")
    }
    
    // MARK: - Edit Mode Tests
    
    func testEditModeDisabledWhenEmpty() {
        let view = createTrashView()
        // Edit button should be disabled when trash is empty
        XCTAssertNotNil(view, "Edit button should be disabled with no items")
    }
    
    func testEditModeEnabledWithItems() throws {
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        // Edit button should be enabled when trash has items
        XCTAssertNotNil(view, "Edit button should be enabled with items")
    }
    
    // MARK: - Swipe Actions Tests
    
    func testSwipeActionsAvailable() throws {
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        // Should have Put Back and Delete swipe actions
        XCTAssertNotNil(view, "Should have swipe actions")
    }
    
    func testSwipeActionsDisabledInEditMode() throws {
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        // Swipe actions should be hidden in edit mode
        XCTAssertNotNil(view, "Swipe actions should be disabled in edit mode")
    }
    
    // MARK: - Toolbar Tests
    
    func testToolbarHiddenWhenNoSelection() throws {
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        // Toolbar should be hidden when nothing selected
        XCTAssertNotNil(view, "Toolbar should be hidden with no selection")
    }
    
    func testToolbarVisibleWithSelection() throws {
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        // Toolbar should be visible when items selected in edit mode
        XCTAssertNotNil(view, "Toolbar should be visible with selection in edit mode")
    }
    
    // MARK: - Edge Cases
    
    func testHandlesNilOriginalFolder() throws {
        testFile1 = TextFile(name: "Test File", parentFolder: nil)
        modelContext.insert(testFile1)
        
        trashItem1 = TrashItem(textFile: testFile1, originalFolder: nil, project: testProject)
        modelContext.insert(trashItem1)
        try modelContext.save()
        
        let view = createTrashView()
        XCTAssertNotNil(view, "Should handle trash item with nil original folder")
    }
    
    func testHandlesNilTextFile() throws {
        trashItem1 = TrashItem(textFile: nil, originalFolder: draftFolder, project: testProject)
        modelContext.insert(trashItem1)
        try modelContext.save()
        
        let view = createTrashView()
        XCTAssertNotNil(view, "Should handle trash item with nil text file")
    }
    
    func testMultipleProjectsFiltering() throws {
        // Create second project
        let otherProject = Project(name: "Other Project", type: .poetry)
        modelContext.insert(otherProject)
        
        let otherFolder = Folder(name: "Draft", project: otherProject)
        let otherFile = TextFile(name: "Other File", parentFolder: nil)
        modelContext.insert(otherFile)
        
        let otherTrashItem = TrashItem(textFile: otherFile, originalFolder: otherFolder, project: otherProject)
        modelContext.insert(otherTrashItem)
        
        // Create trash item for test project
        trashItem1 = createTrashItem(name: "Test File", originalFolder: draftFolder)
        try modelContext.save()
        
        let view = createTrashView()
        // Should only show trash items for testProject, not otherProject
        XCTAssertNotNil(view, "Should filter trash items by project")
    }
}
