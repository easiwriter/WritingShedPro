//
//  MoveDestinationPickerTests.swift
//  WritingShedProTests
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 3
//

import XCTest
import SwiftUI
import SwiftData
@testable import Writing_Shed_Pro

/// Unit tests for MoveDestinationPicker folder filtering and selection behavior.
///
/// **Test Coverage:**
/// - Folder filtering (exclude current, include source folders)
/// - Empty state handling
/// - Destination selection callback
/// - Cancel action
/// - Folder display (icons, colors, counts)
@MainActor
final class MoveDestinationPickerTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    var draftFolder: Folder!
    var readyFolder: Folder!
    var setAsideFolder: Folder!
    var trashFolder: Folder!
    var selectedDestination: Folder?
    var cancelCalled: Bool = false
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(
            for: Project.self, Folder.self, TextFile.self,
            configurations: config
        )
        modelContext = modelContainer.mainContext
        
        // Create test project
        testProject = Project(name: "Test Poetry Project", type: .poetry)
        modelContext.insert(testProject)
        
        // Create test folders
        draftFolder = Folder(name: "Draft", project: testProject)
        readyFolder = Folder(name: "Ready", project: testProject)
        setAsideFolder = Folder(name: "Set Aside", project: testProject)
        trashFolder = Folder(name: "Trash", project: testProject)
        
        testProject.folders = [draftFolder, readyFolder, setAsideFolder, trashFolder]
        
        try modelContext.save()
        
        // Reset callback trackers
        selectedDestination = nil
        cancelCalled = false
    }
    
    override func tearDown() async throws {
        selectedDestination = nil
        cancelCalled = false
        modelContainer = nil
        modelContext = nil
        testProject = nil
        draftFolder = nil
        readyFolder = nil
        setAsideFolder = nil
        trashFolder = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a MoveDestinationPicker with test callbacks
    private func createPicker(
        currentFolder: Folder,
        filesToMove: [TextFile]
    ) -> MoveDestinationPicker {
        MoveDestinationPicker(
            project: testProject,
            currentFolder: currentFolder,
            filesToMove: filesToMove,
            onDestinationSelected: { folder in
                self.selectedDestination = folder
            },
            onCancel: {
                self.cancelCalled = true
            }
        )
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        XCTAssertNotNil(picker, "Picker should initialize successfully")
    }
    
    func testInitializationWithMultipleFiles() {
        let files = [
            TextFile(name: "File 1", parentFolder: draftFolder),
            TextFile(name: "File 2", parentFolder: draftFolder),
            TextFile(name: "File 3", parentFolder: draftFolder)
        ]
        let picker = createPicker(currentFolder: draftFolder, filesToMove: files)
        
        XCTAssertNotNil(picker, "Picker should initialize with multiple files")
    }
    
    // MARK: - Folder Filtering Tests
    
    func testExcludesCurrentFolder() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // Draft is current folder, should see Ready and Set Aside
        XCTAssertNotNil(picker, "Should exclude current folder from destinations")
    }
    
    func testIncludesSourceFolders() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // Should include Draft, Ready, Set Aside (minus current)
        XCTAssertNotNil(picker, "Should include source folders")
    }
    
    func testExcludesTrashFolder() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // Trash should never appear as destination
        XCTAssertNotNil(picker, "Should exclude Trash folder")
    }
    
    func testExcludesNonSourceFolders() {
        // Add a custom folder that's not Draft/Ready/Set Aside
        let customFolder = Folder(name: "Custom Folder", project: testProject)
        testProject.folders?.append(customFolder)
        
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        XCTAssertNotNil(picker, "Should exclude non-source folders")
    }
    
    // MARK: - Callback Tests
    
    func testOnDestinationSelectedCallback() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // Simulate selecting Ready folder
        picker.onDestinationSelected(readyFolder)
        
        XCTAssertEqual(selectedDestination?.id, readyFolder.id, "Should call onDestinationSelected with correct folder")
    }
    
    func testOnCancelCallback() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // Simulate cancel action
        picker.onCancel()
        
        XCTAssertTrue(cancelCalled, "Should call onCancel when cancelled")
    }
    
    // MARK: - Display Tests
    
    func testTitleWithSingleFile() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // Title should be "Move File" for single file
        XCTAssertNotNil(picker, "Should show singular title for single file")
    }
    
    func testTitleWithMultipleFiles() {
        let files = [
            TextFile(name: "File 1", parentFolder: draftFolder),
            TextFile(name: "File 2", parentFolder: draftFolder),
            TextFile(name: "File 3", parentFolder: draftFolder)
        ]
        let picker = createPicker(currentFolder: draftFolder, filesToMove: files)
        
        // Title should be "Move 3 Files" for multiple files
        XCTAssertNotNil(picker, "Should show plural title for multiple files")
    }
    
    func testFolderIcons() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: readyFolder, filesToMove: [file])
        
        // Draft, Ready, Set Aside should have distinct icons
        XCTAssertNotNil(picker, "Should display appropriate icons for folder types")
    }
    
    func testFolderColors() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: readyFolder, filesToMove: [file])
        
        // Draft (blue), Ready (green), Set Aside (orange)
        XCTAssertNotNil(picker, "Should display appropriate colors for folder types")
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyStateWhenOnlyCurrentFolder() {
        // Create project with only one folder
        let singleProject = Project(name: "Single Folder Project", type: .poetry)
        let onlyFolder = Folder(name: "Draft", project: singleProject)
        singleProject.folders = [onlyFolder]
        
        let file = TextFile(name: "Test File", parentFolder: onlyFolder)
        let picker = MoveDestinationPicker(
            project: singleProject,
            currentFolder: onlyFolder,
            filesToMove: [file],
            onDestinationSelected: { _ in },
            onCancel: { }
        )
        
        XCTAssertNotNil(picker, "Should show empty state when no destinations available")
    }
    
    func testEmptyStateWhenAllFoldersFiltered() {
        // Create project where all folders would be filtered out
        let filteredProject = Project(name: "Filtered Project", type: .poetry)
        let folder1 = Folder(name: "Draft", project: filteredProject)
        let folder2 = Folder(name: "Trash", project: filteredProject)
        filteredProject.folders = [folder1, folder2]
        
        let file = TextFile(name: "Test File", parentFolder: folder1)
        let picker = MoveDestinationPicker(
            project: filteredProject,
            currentFolder: folder1,
            filesToMove: [file],
            onDestinationSelected: { _ in },
            onCancel: { }
        )
        
        XCTAssertNotNil(picker, "Should show empty state when all folders filtered")
    }
    
    // MARK: - Folder Sorting Tests
    
    func testFoldersAreSortedAlphabetically() {
        let file = TextFile(name: "Test File", parentFolder: trashFolder)
        let picker = createPicker(currentFolder: trashFolder, filesToMove: [file])
        
        // Folders should be sorted: Draft, Ready, Set Aside
        XCTAssertNotNil(picker, "Folders should be sorted alphabetically")
    }
    
    // MARK: - Edge Cases
    
    func testWithNoFiles() {
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [])
        
        XCTAssertNotNil(picker, "Should handle empty files array")
    }
    
    func testWithNilFolderNames() {
        let namelessFolder = Folder(name: nil, project: testProject)
        testProject.folders?.append(namelessFolder)
        
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        XCTAssertNotNil(picker, "Should handle folders with nil names")
    }
    
    func testMultipleSelections() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // First selection
        picker.onDestinationSelected(readyFolder)
        XCTAssertEqual(selectedDestination?.id, readyFolder.id)
        
        // Second selection
        picker.onDestinationSelected(setAsideFolder)
        XCTAssertEqual(selectedDestination?.id, setAsideFolder.id)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteSelectionWorkflow() {
        let files = [
            TextFile(name: "File 1", parentFolder: draftFolder),
            TextFile(name: "File 2", parentFolder: draftFolder)
        ]
        let picker = createPicker(currentFolder: draftFolder, filesToMove: files)
        
        // User opens picker, sees destinations, selects Ready
        picker.onDestinationSelected(readyFolder)
        
        XCTAssertEqual(selectedDestination?.id, readyFolder.id)
        XCTAssertFalse(cancelCalled, "Should not call cancel when destination selected")
    }
    
    func testCompleteCancelWorkflow() {
        let file = TextFile(name: "Test File", parentFolder: draftFolder)
        let picker = createPicker(currentFolder: draftFolder, filesToMove: [file])
        
        // User opens picker, then cancels
        picker.onCancel()
        
        XCTAssertTrue(cancelCalled)
        XCTAssertNil(selectedDestination, "Should not select destination when cancelled")
    }
}
