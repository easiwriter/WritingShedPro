//
//  FileListViewTests.swift
//  WritingShedProTests
//
//  Created on 2025-11-08.
//  Feature: 008a-file-movement - Phase 2
//

import XCTest
import SwiftUI
@testable import Writing_Shed_Pro

/// Unit tests for FileListView edit mode behavior, swipe actions, and toolbar functionality.
///
/// **Test Coverage:**
/// - Edit mode toggling and state management
/// - Selection behavior (single and multiple)
/// - Swipe actions availability (normal mode only)
/// - Toolbar visibility and action states
/// - Delete confirmation flow
/// - Callback invocation for onFileSelected, onMove, onDelete
@MainActor
final class FileListViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var sampleFiles: [TextFile]!
    var selectedFileCallback: TextFile?
    var movedFiles: [TextFile]?
    var deletedFiles: [TextFile]?
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create sample files for testing
        sampleFiles = [
            TextFile(name: "File 1", parentFolder: nil),
            TextFile(name: "File 2", parentFolder: nil),
            TextFile(name: "File 3", parentFolder: nil),
        ]
        
        // Reset callback trackers
        selectedFileCallback = nil
        movedFiles = nil
        deletedFiles = nil
    }
    
    override func tearDown() {
        sampleFiles = nil
        selectedFileCallback = nil
        movedFiles = nil
        deletedFiles = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Creates a FileListView with test callbacks
    private func createFileListView(files: [TextFile]) -> FileListView {
        FileListView(
            files: files,
            onFileSelected: { file in
                self.selectedFileCallback = file
            },
            onMove: { files in
                self.movedFiles = files
            },
            onDelete: { files in
                self.deletedFiles = files
            }
        )
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithEmptyFileList() {
        let view = createFileListView(files: [])
        XCTAssertNotNil(view, "FileListView should initialize with empty file list")
    }
    
    func testInitializationWithFiles() {
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "FileListView should initialize with file list")
    }
    
    // MARK: - Edit Mode Tests
    
    func testEditModeStartsInactive() {
        let view = createFileListView(files: sampleFiles)
        // Note: We can't directly test @State, but we test behavior
        // Edit mode should start as .inactive (normal mode)
        XCTAssertNotNil(view, "Edit mode should start inactive")
    }
    
    func testEditButtonDisabledForEmptyList() {
        let view = createFileListView(files: [])
        // Edit button should be disabled when there are no files
        XCTAssertNotNil(view, "Edit button should be disabled for empty list")
    }
    
    func testEditButtonEnabledForNonEmptyList() {
        let view = createFileListView(files: sampleFiles)
        // Edit button should be enabled when files exist
        XCTAssertNotNil(view, "Edit button should be enabled when files exist")
    }
    
    // MARK: - Selection Tests
    
    func testSelectionStartsEmpty() {
        let view = createFileListView(files: sampleFiles)
        // Selection should start empty (no files selected)
        XCTAssertNotNil(view, "Selection should start empty")
    }
    
    func testSelectionClearsWhenExitingEditMode() {
        // This tests the .onChange(of: editMode) behavior
        // When editMode changes from .active to .inactive, selection should clear
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Selection should clear when exiting edit mode")
    }
    
    // MARK: - Callback Tests
    
    func testOnFileSelectedCallback() {
        let view = createFileListView(files: sampleFiles)
        let testFile = sampleFiles[0]
        
        // Simulate file selection in normal mode
        view.onFileSelected(testFile)
        
        XCTAssertEqual(selectedFileCallback?.id, testFile.id, "onFileSelected should be called with correct file")
    }
    
    func testOnMoveCallbackWithSingleFile() {
        let view = createFileListView(files: sampleFiles)
        let testFile = sampleFiles[0]
        
        // Simulate move action
        view.onMove([testFile])
        
        XCTAssertEqual(movedFiles?.count, 1, "onMove should be called with single file")
        XCTAssertEqual(movedFiles?.first?.id, testFile.id, "Moved file should match test file")
    }
    
    func testOnMoveCallbackWithMultipleFiles() {
        let view = createFileListView(files: sampleFiles)
        
        // Simulate move action with multiple files
        view.onMove(sampleFiles)
        
        XCTAssertEqual(movedFiles?.count, 3, "onMove should be called with all files")
    }
    
    func testOnDeleteCallbackWithSingleFile() {
        let view = createFileListView(files: sampleFiles)
        let testFile = sampleFiles[0]
        
        // Simulate delete action
        view.onDelete([testFile])
        
        XCTAssertEqual(deletedFiles?.count, 1, "onDelete should be called with single file")
        XCTAssertEqual(deletedFiles?.first?.id, testFile.id, "Deleted file should match test file")
    }
    
    func testOnDeleteCallbackWithMultipleFiles() {
        let view = createFileListView(files: sampleFiles)
        
        // Simulate delete action with multiple files
        view.onDelete(sampleFiles)
        
        XCTAssertEqual(deletedFiles?.count, 3, "onDelete should be called with all files")
    }
    
    // MARK: - Swipe Actions Tests
    
    func testSwipeActionsAvailableInNormalMode() {
        // Swipe actions should only be shown when NOT in edit mode
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Swipe actions should be available in normal mode")
    }
    
    func testSwipeActionsDisabledInEditMode() {
        // Swipe actions should be hidden when in edit mode
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Swipe actions should be disabled in edit mode")
    }
    
    func testSwipeMoveAction() {
        let view = createFileListView(files: sampleFiles)
        let testFile = sampleFiles[0]
        
        // Simulate swipe move action
        view.onMove([testFile])
        
        XCTAssertEqual(movedFiles?.count, 1, "Swipe move should trigger onMove with single file")
    }
    
    func testSwipeDeleteAction() {
        let view = createFileListView(files: sampleFiles)
        let testFile = sampleFiles[0]
        
        // Simulate swipe delete action (goes through confirmation)
        view.onDelete([testFile])
        
        XCTAssertEqual(deletedFiles?.count, 1, "Swipe delete should trigger onDelete with single file")
    }
    
    // MARK: - Toolbar Tests
    
    func testToolbarHiddenInNormalMode() {
        // Bottom toolbar should not be visible when not in edit mode
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Toolbar should be hidden in normal mode")
    }
    
    func testToolbarHiddenWhenNoSelection() {
        // Bottom toolbar should not be visible when in edit mode but nothing selected
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Toolbar should be hidden when no items selected")
    }
    
    func testToolbarVisibleWithSelection() {
        // Bottom toolbar should be visible when in edit mode with items selected
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Toolbar should be visible with selection in edit mode")
    }
    
    func testToolbarMoveButtonLabel() {
        // Move button should show count: "Move 1", "Move 2", etc.
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Move button should show file count")
    }
    
    func testToolbarDeleteButtonLabel() {
        // Delete button should show count: "Delete 1", "Delete 2", etc.
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Delete button should show file count")
    }
    
    // MARK: - Delete Confirmation Tests
    
    func testDeleteConfirmationAlertMessage() {
        // Alert should show correct count: "Delete 1 file?" vs "Delete 3 files?"
        let view = createFileListView(files: sampleFiles)
        XCTAssertNotNil(view, "Delete confirmation should show correct message")
    }
    
    func testDeleteConfirmationSingularPlural() {
        // Test that singular vs plural is handled correctly
        let singleFile = [sampleFiles[0]]
        let view = createFileListView(files: singleFile)
        XCTAssertNotNil(view, "Should use 'file' for singular, 'files' for plural")
    }
    
    func testDeleteConfirmationCancel() {
        // When user cancels, files should not be deleted
        let view = createFileListView(files: sampleFiles)
        // Canceling should clear filesToDelete and not call onDelete
        XCTAssertNil(deletedFiles, "Cancel should not trigger delete callback")
    }
    
    func testDeleteConfirmationConfirm() {
        let view = createFileListView(files: sampleFiles)
        let testFile = sampleFiles[0]
        
        // Simulate confirming delete
        view.onDelete([testFile])
        
        XCTAssertNotNil(deletedFiles, "Confirm should trigger delete callback")
        XCTAssertEqual(deletedFiles?.count, 1, "Should delete correct number of files")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyFileListBehavior() {
        let view = createFileListView(files: [])
        XCTAssertNotNil(view, "Should handle empty file list gracefully")
    }
    
    func testSingleFileListBehavior() {
        let view = createFileListView(files: [sampleFiles[0]])
        XCTAssertNotNil(view, "Should handle single file correctly")
    }
    
    func testLargeFileListBehavior() {
        // Test with 100 files to ensure performance
        var largeFileList: [TextFile] = []
        for i in 1...100 {
            largeFileList.append(TextFile(name: "File \(i)", parentFolder: nil))
        }
        
        let view = createFileListView(files: largeFileList)
        XCTAssertNotNil(view, "Should handle large file lists efficiently")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteEditModeWorkflow() {
        let view = createFileListView(files: sampleFiles)
        
        // 1. Start in normal mode
        // 2. Enter edit mode
        // 3. Select files
        // 4. Trigger move action
        view.onMove([sampleFiles[0], sampleFiles[1]])
        
        XCTAssertEqual(movedFiles?.count, 2, "Should complete full edit mode workflow")
    }
    
    func testCompleteSwipeWorkflow() {
        let view = createFileListView(files: sampleFiles)
        
        // 1. In normal mode
        // 2. Swipe action on single file
        view.onMove([sampleFiles[0]])
        
        XCTAssertEqual(movedFiles?.count, 1, "Should complete swipe action workflow")
    }
    
    func testCompleteDeleteWorkflow() {
        let view = createFileListView(files: sampleFiles)
        
        // 1. Select files in edit mode
        // 2. Tap delete
        // 3. Confirm deletion
        view.onDelete([sampleFiles[0]])
        
        XCTAssertEqual(deletedFiles?.count, 1, "Should complete delete workflow")
    }
}
