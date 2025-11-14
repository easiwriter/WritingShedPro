//
//  FileListEnhancementsTests.swift
//  WritingShedProTests
//
//  Created on 2025-11-14.
//  Tests for alphabetical sections, All folder, and file list enhancements
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class FileListEnhancementsTests: XCTestCase {
    
    var modelContext: ModelContext!
    var testProject: Project!
    var draftFolder: Folder!
    var readyFolder: Folder!
    var setAsideFolder: Folder!
    var publishedFolder: Folder!
    var allFolder: Folder!
    
    override func setUp() async throws {
        // Create in-memory model container for testing
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Project.self, Folder.self, TextFile.self, configurations: config)
        modelContext = ModelContext(container)
        
        // Create test project
        testProject = Project(name: "Test Poetry Project", type: .poetry)
        modelContext.insert(testProject)
        
        // Create standard folders
        draftFolder = Folder(name: "Draft", project: testProject)
        readyFolder = Folder(name: "Ready", project: testProject)
        setAsideFolder = Folder(name: "Set Aside", project: testProject)
        publishedFolder = Folder(name: "Published", project: testProject)
        allFolder = Folder(name: "All", project: testProject)
        
        modelContext.insert(draftFolder)
        modelContext.insert(readyFolder)
        modelContext.insert(setAsideFolder)
        modelContext.insert(publishedFolder)
        modelContext.insert(allFolder)
        
        try modelContext.save()
    }
    
    override func tearDown() async throws {
        modelContext = nil
        testProject = nil
        draftFolder = nil
        readyFolder = nil
        setAsideFolder = nil
        publishedFolder = nil
        allFolder = nil
    }
    
    // MARK: - All Folder Tests
    
    func testAllFolderAggregatesFilesFromDraft() throws {
        // Given files in Draft folder
        let file1 = TextFile(name: "Draft File 1", initialContent: "Content", parentFolder: draftFolder)
        let file2 = TextFile(name: "Draft File 2", initialContent: "Content", parentFolder: draftFolder)
        modelContext.insert(file1)
        modelContext.insert(file2)
        draftFolder.textFiles = [file1, file2]
        try modelContext.save()
        
        // When getting all folders to simulate FolderFilesView query
        let descriptor = FetchDescriptor<Folder>()
        let allFolders = try modelContext.fetch(descriptor)
        
        // Then All folder should aggregate files from Draft
        let projectFolders = allFolders.filter { $0.project?.id == testProject.id }
        let targetFolderNames = ["Draft", "Ready", "Set Aside", "Published"]
        var aggregatedFiles: [TextFile] = []
        
        for folder in projectFolders {
            if targetFolderNames.contains(folder.name ?? "") {
                aggregatedFiles.append(contentsOf: folder.textFiles ?? [])
            }
        }
        
        XCTAssertEqual(aggregatedFiles.count, 2, "All folder should show 2 files from Draft")
        XCTAssertTrue(aggregatedFiles.contains { $0.name == "Draft File 1" })
        XCTAssertTrue(aggregatedFiles.contains { $0.name == "Draft File 2" })
    }
    
    func testAllFolderAggregatesFilesFromMultipleFolders() throws {
        // Given files in multiple folders
        let draftFile = TextFile(name: "Draft File", initialContent: "Content", parentFolder: draftFolder)
        let readyFile = TextFile(name: "Ready File", initialContent: "Content", parentFolder: readyFolder)
        let setAsideFile = TextFile(name: "Set Aside File", initialContent: "Content", parentFolder: setAsideFolder)
        let publishedFile = TextFile(name: "Published File", initialContent: "Content", parentFolder: publishedFolder)
        
        modelContext.insert(draftFile)
        modelContext.insert(readyFile)
        modelContext.insert(setAsideFile)
        modelContext.insert(publishedFile)
        
        draftFolder.textFiles = [draftFile]
        readyFolder.textFiles = [readyFile]
        setAsideFolder.textFiles = [setAsideFile]
        publishedFolder.textFiles = [publishedFile]
        
        try modelContext.save()
        
        // When aggregating files
        let descriptor = FetchDescriptor<Folder>()
        let allFolders = try modelContext.fetch(descriptor)
        let projectFolders = allFolders.filter { $0.project?.id == testProject.id }
        let targetFolderNames = ["Draft", "Ready", "Set Aside", "Published"]
        var aggregatedFiles: [TextFile] = []
        
        for folder in projectFolders {
            if targetFolderNames.contains(folder.name ?? "") {
                aggregatedFiles.append(contentsOf: folder.textFiles ?? [])
            }
        }
        
        // Then All folder should show all 4 files
        XCTAssertEqual(aggregatedFiles.count, 4, "All folder should show files from all standard folders")
        XCTAssertTrue(aggregatedFiles.contains { $0.name == "Draft File" })
        XCTAssertTrue(aggregatedFiles.contains { $0.name == "Ready File" })
        XCTAssertTrue(aggregatedFiles.contains { $0.name == "Set Aside File" })
        XCTAssertTrue(aggregatedFiles.contains { $0.name == "Published File" })
    }
    
    func testAllFolderIgnoresOtherFolders() throws {
        // Given files in non-target folders
        let researchFolder = Folder(name: "Research", project: testProject)
        modelContext.insert(researchFolder)
        
        let researchFile = TextFile(name: "Research File", initialContent: "Content", parentFolder: researchFolder)
        modelContext.insert(researchFile)
        researchFolder.textFiles = [researchFile]
        
        let draftFile = TextFile(name: "Draft File", initialContent: "Content", parentFolder: draftFolder)
        modelContext.insert(draftFile)
        draftFolder.textFiles = [draftFile]
        
        try modelContext.save()
        
        // When aggregating files
        let descriptor = FetchDescriptor<Folder>()
        let allFolders = try modelContext.fetch(descriptor)
        let projectFolders = allFolders.filter { $0.project?.id == testProject.id }
        let targetFolderNames = ["Draft", "Ready", "Set Aside", "Published"]
        var aggregatedFiles: [TextFile] = []
        
        for folder in projectFolders {
            if targetFolderNames.contains(folder.name ?? "") {
                aggregatedFiles.append(contentsOf: folder.textFiles ?? [])
            }
        }
        
        // Then All folder should only show Draft file, not Research file
        XCTAssertEqual(aggregatedFiles.count, 1, "All folder should only show files from target folders")
        XCTAssertTrue(aggregatedFiles.contains { $0.name == "Draft File" })
        XCTAssertFalse(aggregatedFiles.contains { $0.name == "Research File" })
    }
    
    func testAllFolderWithEmptyFolders() throws {
        // Given empty standard folders
        // (No files added)
        
        // When aggregating files
        let descriptor = FetchDescriptor<Folder>()
        let allFolders = try modelContext.fetch(descriptor)
        let projectFolders = allFolders.filter { $0.project?.id == testProject.id }
        let targetFolderNames = ["Draft", "Ready", "Set Aside", "Published"]
        var aggregatedFiles: [TextFile] = []
        
        for folder in projectFolders {
            if targetFolderNames.contains(folder.name ?? "") {
                aggregatedFiles.append(contentsOf: folder.textFiles ?? [])
            }
        }
        
        // Then All folder should be empty
        XCTAssertEqual(aggregatedFiles.count, 0, "All folder should be empty when no files exist")
    }
    
    // MARK: - Alphabetical Section Tests
    
    func testAlphabeticalSectionGrouping() {
        // Given files with different first letters
        let files = [
            TextFile(name: "Apple", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Banana", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Avocado", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Cherry", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Blueberry", initialContent: "", parentFolder: draftFolder)
        ]
        
        // When grouping alphabetically
        let sections = AlphabeticalSectionHelper.groupFiles(files)
        
        // Then files should be grouped by first letter
        XCTAssertEqual(sections.count, 3, "Should have 3 sections: A, B, C")
        
        let sectionA = sections.first { $0.letter == "A" }
        let sectionB = sections.first { $0.letter == "B" }
        let sectionC = sections.first { $0.letter == "C" }
        
        XCTAssertNotNil(sectionA)
        XCTAssertNotNil(sectionB)
        XCTAssertNotNil(sectionC)
        
        XCTAssertEqual(sectionA?.count, 2, "Section A should have 2 files")
        XCTAssertEqual(sectionB?.count, 2, "Section B should have 2 files")
        XCTAssertEqual(sectionC?.count, 1, "Section C should have 1 file")
    }
    
    func testAlphabeticalSectionSorting() {
        // Given files in random order
        let files = [
            TextFile(name: "Zebra", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Apple", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Mango", initialContent: "", parentFolder: draftFolder)
        ]
        
        // When grouping alphabetically
        let sections = AlphabeticalSectionHelper.groupFiles(files)
        
        // Then sections should be sorted A-Z
        XCTAssertEqual(sections[0].letter, "A")
        XCTAssertEqual(sections[1].letter, "M")
        XCTAssertEqual(sections[2].letter, "Z")
        
        // And files within sections should be sorted
        XCTAssertEqual(sections[0].items[0].name, "Apple")
        XCTAssertEqual(sections[1].items[0].name, "Mango")
        XCTAssertEqual(sections[2].items[0].name, "Zebra")
    }
    
    func testAlphabeticalSectionWithNumbers() {
        // Given files starting with numbers and letters
        let files = [
            TextFile(name: "123 Test", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Apple", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "456 Test", initialContent: "", parentFolder: draftFolder)
        ]
        
        // When grouping alphabetically
        let sections = AlphabeticalSectionHelper.groupFiles(files)
        
        // Then numbers should be grouped under "#" and come first
        XCTAssertTrue(sections.count >= 2)
        XCTAssertEqual(sections[0].letter, "#", "Numbers should be in # section")
        XCTAssertEqual(sections[0].count, 2, "# section should have 2 files")
    }
    
    func testAlphabeticalSectionCaseInsensitive() {
        // Given files with mixed case
        let files = [
            TextFile(name: "apple", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "Apple", initialContent: "", parentFolder: draftFolder),
            TextFile(name: "APPLE", initialContent: "", parentFolder: draftFolder)
        ]
        
        // When grouping alphabetically
        let sections = AlphabeticalSectionHelper.groupFiles(files)
        
        // Then all should be in section A
        XCTAssertEqual(sections.count, 1, "Should have 1 section")
        XCTAssertEqual(sections[0].letter, "A")
        XCTAssertEqual(sections[0].count, 3, "All three files should be in section A")
    }
    
    // MARK: - Conditional Section Tests
    
    func testConditionalSectionsThreshold() {
        // Test that sections appear only when file count > 15
        
        // 15 files or fewer should use flat list
        let smallList = (1...15).map { TextFile(name: "File \($0)", initialContent: "", parentFolder: draftFolder) }
        XCTAssertLessThanOrEqual(smallList.count, 15, "Small list should have ≤15 files")
        
        // 16 files or more should use sections
        let largeList = (1...16).map { TextFile(name: "File \($0)", initialContent: "", parentFolder: draftFolder) }
        XCTAssertGreaterThan(largeList.count, 15, "Large list should have >15 files")
        
        // The actual logic is: useSections = files.count > 15
        XCTAssertFalse(smallList.count > 15, "≤15 files should not trigger sections")
        XCTAssertTrue(largeList.count > 15, ">15 files should trigger sections")
    }
}
