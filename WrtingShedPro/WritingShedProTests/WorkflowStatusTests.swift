//
//  WorkflowStatusTests.swift
//  Writing Shed ProTests
//
//  Created on 6 January 2026.
//  Tests for WorkflowStatus enum and related functionality
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class WorkflowStatusTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([Project.self, Folder.self, TextFile.self, Version.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - WorkflowStatus Enum Tests
    
    func testWorkflowStatus_AllCases() {
        // Verify all expected cases exist
        let allCases = WorkflowStatus.allCases
        XCTAssertEqual(allCases.count, 4, "Should have 4 workflow status cases")
        
        XCTAssertTrue(allCases.contains(.draft))
        XCTAssertTrue(allCases.contains(.ready))
        XCTAssertTrue(allCases.contains(.setAside))
        XCTAssertTrue(allCases.contains(.published))
    }
    
    func testWorkflowStatus_RawValues() {
        // Verify raw values for serialization
        XCTAssertEqual(WorkflowStatus.draft.rawValue, "draft")
        XCTAssertEqual(WorkflowStatus.ready.rawValue, "ready")
        XCTAssertEqual(WorkflowStatus.setAside.rawValue, "setAside")
        XCTAssertEqual(WorkflowStatus.published.rawValue, "published")
    }
    
    func testWorkflowStatus_SystemImages() {
        // Verify each status has a system image
        for status in WorkflowStatus.allCases {
            XCTAssertFalse(status.systemImage.isEmpty, "\(status) should have a system image")
        }
    }
    
    func testWorkflowStatus_Colors() {
        // Verify each status has a color
        for status in WorkflowStatus.allCases {
            XCTAssertNotNil(status.color, "\(status) should have a color")
        }
        
        // Verify specific colors
        XCTAssertEqual(WorkflowStatus.draft.color, .systemBlue)
        XCTAssertEqual(WorkflowStatus.ready.color, .systemGreen)
        XCTAssertEqual(WorkflowStatus.setAside.color, .systemRed)
        XCTAssertEqual(WorkflowStatus.published.color, .label)
    }
    
    func testWorkflowStatus_LocalizedNames() {
        // Verify each status has a localized name
        for status in WorkflowStatus.allCases {
            XCTAssertFalse(status.localizedName.isEmpty, "\(status) should have a localized name")
        }
    }
    
    // MARK: - TextFile WorkflowStatus Tests
    
    func testTextFile_WorkflowStatusProperty() {
        // Create a text file
        let textFile = TextFile(name: "Test File", initialContent: "Content")
        modelContext.insert(textFile)
        
        // Default should be nil (no status)
        XCTAssertNil(textFile.workflowStatus, "New file should have nil workflow status")
        
        // Set status to draft
        textFile.workflowStatus = .draft
        XCTAssertEqual(textFile.workflowStatus, .draft)
        XCTAssertEqual(textFile.workflowStatusRaw, "draft")
        
        // Change to ready
        textFile.workflowStatus = .ready
        XCTAssertEqual(textFile.workflowStatus, .ready)
        XCTAssertEqual(textFile.workflowStatusRaw, "ready")
        
        // Change to published
        textFile.workflowStatus = .published
        XCTAssertEqual(textFile.workflowStatus, .published)
        XCTAssertEqual(textFile.workflowStatusRaw, "published")
        
        // Set back to nil
        textFile.workflowStatus = nil
        XCTAssertNil(textFile.workflowStatus)
        XCTAssertNil(textFile.workflowStatusRaw)
    }
    
    func testTextFile_WorkflowStatusPersistence() throws {
        // Create a text file with status
        let textFile = TextFile(name: "Persisted File", initialContent: "Content")
        textFile.workflowStatus = .setAside
        modelContext.insert(textFile)
        
        try modelContext.save()
        
        // Fetch the file
        let descriptor = FetchDescriptor<TextFile>(
            predicate: #Predicate { $0.name == "Persisted File" }
        )
        let results = try modelContext.fetch(descriptor)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.workflowStatus, .setAside)
    }
    
    // MARK: - Content Folder Tests
    
    func testContentFolders_AreFileOnly() {
        // Create a poetry project
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
        
        let folders = project.folders ?? []
        
        // Poems folder should allow files but not subfolders
        if let poemsFolder = folders.first(where: { $0.name == "Poems" }) {
            XCTAssertTrue(FolderCapabilityService.canAddFile(to: poemsFolder), "Poems should allow files")
            XCTAssertFalse(FolderCapabilityService.canAddSubfolder(to: poemsFolder), "Poems should not allow subfolders")
            XCTAssertTrue(FolderCapabilityService.isContentFolder(poemsFolder), "Poems should be a content folder")
        } else {
            XCTFail("Poems folder should exist")
        }
    }
    
    func testContentFolders_ForAllProjectTypes() {
        // Test Poetry -> Poems
        let poetryProject = Project(name: "Poetry", type: .poetry)
        modelContext.insert(poetryProject)
        ProjectTemplateService.createDefaultFolders(for: poetryProject, in: modelContext)
        XCTAssertNotNil((poetryProject.folders ?? []).first(where: { $0.name == "Poems" }), "Poetry should have Poems folder")
        
        // Test Fiction -> Scenes
        let fictionProject = Project(name: "Fiction", type: .fiction)
        modelContext.insert(fictionProject)
        ProjectTemplateService.createDefaultFolders(for: fictionProject, in: modelContext)
        XCTAssertNotNil((fictionProject.folders ?? []).first(where: { $0.name == "Scenes" }), "Fiction should have Scenes folder")
        
        // Test Drama -> Scenes (drama uses Scenes folder for scene content)
        let dramaProject = Project(name: "Drama", type: .drama)
        modelContext.insert(dramaProject)
        ProjectTemplateService.createDefaultFolders(for: dramaProject, in: modelContext)
        XCTAssertNotNil((dramaProject.folders ?? []).first(where: { $0.name == "Scenes" }), "Drama should have Scenes folder")
    }
    
    // MARK: - Workflow Filtering Tests
    
    func testFiltering_ByWorkflowStatus() throws {
        // Create files with different statuses
        let file1 = TextFile(name: "Draft 1", initialContent: "")
        file1.workflowStatus = .draft
        
        let file2 = TextFile(name: "Draft 2", initialContent: "")
        file2.workflowStatus = .draft
        
        let file3 = TextFile(name: "Ready 1", initialContent: "")
        file3.workflowStatus = .ready
        
        let file4 = TextFile(name: "Published 1", initialContent: "")
        file4.workflowStatus = .published
        
        let file5 = TextFile(name: "No Status", initialContent: "")
        // file5 has no status (nil)
        
        let files = [file1, file2, file3, file4, file5]
        
        // Filter by draft
        let draftFiles = files.filter { $0.workflowStatus == .draft }
        XCTAssertEqual(draftFiles.count, 2)
        
        // Filter by ready
        let readyFiles = files.filter { $0.workflowStatus == .ready }
        XCTAssertEqual(readyFiles.count, 1)
        
        // Filter by published
        let publishedFiles = files.filter { $0.workflowStatus == .published }
        XCTAssertEqual(publishedFiles.count, 1)
        
        // Filter by nil (no status)
        let noStatusFiles = files.filter { $0.workflowStatus == nil }
        XCTAssertEqual(noStatusFiles.count, 1)
        
        // All files (no filter)
        XCTAssertEqual(files.count, 5)
    }
}
