//
//  TextFileVersionTests.swift
//  WritingShedProTests
//
//  Tests for TextFile version management functionality
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class TextFileVersionTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testFile: TextFile!
    var testFolder: Folder!
    
    override func setUpWithError() throws {
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        modelContext = ModelContext(modelContainer)
        
        // Create a test folder and file
        testFolder = Folder(name: "Test Folder")
        modelContext.insert(testFolder)
        
        testFile = TextFile(name: "Test File", initialContent: "Initial", parentFolder: testFolder)
        modelContext.insert(testFile)
        
        try modelContext.save()
    }
    
    override func tearDownWithError() throws {
        testFile = nil
        testFolder = nil
        modelContext = nil
        modelContainer = nil
    }
    
    // MARK: - Version Creation Tests
    
    func testNewFileHasOneVersion() {
        XCTAssertEqual(testFile.versions?.count, 1, "New file should have exactly one version")
    }
    
    func testAddVersionCreatesNewVersion() {
        let initialCount = testFile.versions?.count ?? 0
        
        testFile.addVersion()
        
        XCTAssertEqual(testFile.versions?.count, initialCount + 1, "Adding version should increment count")
    }
    
    func testAddVersionIncrementsVersionNumber() {
        // Get initial max version number
        let initialMax = testFile.versions?.map { $0.versionNumber }.max() ?? 0
        
        testFile.addVersion()
        
        let newMax = testFile.versions?.map { $0.versionNumber }.max() ?? 0
        XCTAssertEqual(newMax, initialMax + 1, "New version should have incremented version number")
    }
    
    func testAddVersionSetsCurrentToNew() {
        testFile.addVersion()
        
        // Current version should be the latest
        XCTAssertTrue(testFile.atLastVersion(), "After adding version, should be at last version")
    }
    
    // MARK: - Version Navigation Tests
    
    func testAtFirstVersionWithSingleVersion() {
        XCTAssertTrue(testFile.atFirstVersion(), "Single version file should be at first version")
    }
    
    func testAtLastVersionWithSingleVersion() {
        XCTAssertTrue(testFile.atLastVersion(), "Single version file should be at last version")
    }
    
    func testChangeVersionPrevious() {
        // Add two more versions (total 3)
        testFile.addVersion()
        testFile.addVersion()
        
        // Should be at version 3 (index 2)
        XCTAssertTrue(testFile.atLastVersion())
        
        // Go to previous
        testFile.changeVersion(by: -1)
        
        XCTAssertFalse(testFile.atLastVersion(), "Should not be at last after going previous")
        XCTAssertFalse(testFile.atFirstVersion(), "Should not be at first (middle version)")
    }
    
    func testChangeVersionNext() {
        // Add two more versions
        testFile.addVersion()
        testFile.addVersion()
        
        // Go to first
        testFile.currentVersionIndex = 0
        XCTAssertTrue(testFile.atFirstVersion())
        
        // Go to next
        testFile.changeVersion(by: 1)
        
        XCTAssertFalse(testFile.atFirstVersion(), "Should not be at first after going next")
    }
    
    func testChangeVersionDoesNotGoBelowZero() {
        testFile.currentVersionIndex = 0
        
        testFile.changeVersion(by: -1)
        
        XCTAssertEqual(testFile.currentVersionIndex, 0, "Should not go below 0")
    }
    
    func testChangeVersionDoesNotExceedCount() {
        testFile.addVersion()
        testFile.addVersion()
        
        let lastIndex = (testFile.versions?.count ?? 1) - 1
        testFile.currentVersionIndex = lastIndex
        
        testFile.changeVersion(by: 1)
        
        XCTAssertEqual(testFile.currentVersionIndex, lastIndex, "Should not exceed version count")
    }
    
    // MARK: - Delete Version Tests
    
    func testDeleteVersionWithSingleVersionDoesNothing() {
        XCTAssertEqual(testFile.versions?.count, 1)
        
        testFile.deleteVersion()
        
        XCTAssertEqual(testFile.versions?.count, 1, "Should not delete the only version")
    }
    
    func testDeleteVersionRemovesVersion() {
        testFile.addVersion()
        testFile.addVersion()
        XCTAssertEqual(testFile.versions?.count, 3)
        
        testFile.deleteVersion()
        
        XCTAssertEqual(testFile.versions?.count, 2, "Should have one less version after delete")
    }
    
    func testDeleteVersionDeletesCurrentVersion() {
        // Create versions with different content
        testFile.currentVersion?.content = "Version 1"
        
        testFile.addVersion()
        testFile.currentVersion?.content = "Version 2"
        
        testFile.addVersion()
        testFile.currentVersion?.content = "Version 3"
        
        // Navigate to version 2 (middle)
        testFile.currentVersionIndex = 1
        XCTAssertEqual(testFile.currentVersion?.content, "Version 2")
        
        // Delete version 2
        testFile.deleteVersion()
        
        // Should now have versions 1 and 3
        let contents = testFile.versions?.map { $0.content }.sorted()
        XCTAssertEqual(contents, ["Version 1", "Version 3"], "Should have deleted Version 2")
    }
    
    func testDeleteVersionAdjustsIndexWhenDeletingLast() {
        testFile.addVersion()
        testFile.addVersion()
        
        // Go to last version
        testFile.currentVersionIndex = 2
        XCTAssertTrue(testFile.atLastVersion())
        
        // Delete last version
        testFile.deleteVersion()
        
        // Index should adjust to stay in bounds
        XCTAssertTrue(testFile.currentVersionIndex < (testFile.versions?.count ?? 0), 
                      "Index should be within bounds after deleting last")
    }
    
    func testDeleteVersionFromSortedPosition() {
        // This tests the bug fix where versions are sorted by versionNumber
        // but stored unsorted in the array
        
        // Create 3 versions
        testFile.currentVersion?.content = "One"
        testFile.addVersion()
        testFile.currentVersion?.content = "Two"
        testFile.addVersion()
        testFile.currentVersion?.content = "Three"
        
        // Navigate to middle version (index 1 in sorted order)
        testFile.currentVersionIndex = 1
        
        // Verify we're on "Two"
        XCTAssertEqual(testFile.currentVersion?.content, "Two")
        
        // Delete middle version
        testFile.deleteVersion()
        
        // Should only have "One" and "Three"
        XCTAssertEqual(testFile.versions?.count, 2)
        
        // Navigate through remaining versions
        testFile.currentVersionIndex = 0
        let firstContent = testFile.currentVersion?.content
        
        testFile.currentVersionIndex = 1
        let secondContent = testFile.currentVersion?.content
        
        let remainingContents = [firstContent, secondContent].compactMap { $0 }.sorted()
        XCTAssertEqual(remainingContents, ["One", "Three"], "Should have 'One' and 'Three', not 'Two'")
    }

    func testSwitchToVersionNumber_UsesSortedSpaceWhenArrayUnsorted() {
        // Build 3 versions with explicit content.
        testFile.currentVersion?.content = "One"
        testFile.addVersion()
        testFile.currentVersion?.content = "Two"
        testFile.addVersion()
        testFile.currentVersion?.content = "Three"

        guard let v1 = testFile.versions?.first(where: { $0.versionNumber == 1 }),
              let v2 = testFile.versions?.first(where: { $0.versionNumber == 2 }),
              let v3 = testFile.versions?.first(where: { $0.versionNumber == 3 }) else {
            XCTFail("Missing expected versions")
            return
        }

        // Force unsorted backing array to mimic relationship ordering edge cases.
        testFile.versions = [v3, v1, v2]

        // Select version number 2 and verify currentVersion resolves to "Two".
        testFile.switchToVersionNumber(2)
        XCTAssertEqual(testFile.currentVersion?.content, "Two")
    }
    
    // MARK: - Version Label Tests
    
    func testVersionLabelFormat() {
        let label = testFile.versionLabel()
        XCTAssertEqual(label, "v1/1", "Single version should show compact label format")
    }
    
    func testVersionLabelUpdatesWithMultipleVersions() {
        testFile.addVersion()
        testFile.addVersion()
        
        testFile.currentVersionIndex = 1
        let label = testFile.versionLabel()
        
        XCTAssertEqual(label, "v2/3", "Should show current position in compact label format")
    }
}
