//
//  SubmissionFileTests.swift
//  Writing Shed ProTests
//
//  Tests for submission file adding logic:
//  - Creating submissions from selected files
//  - Adding files to existing submissions (no duplicates)
//  - Loading available files by workflowStatus (not folder name)
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class SubmissionFileTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self,
            TrashItem.self, StyleSheet.self, TextStyleModel.self,
            PageSetup.self, PrinterPaper.self,
            Publication.self, Submission.self, SubmittedFile.self,
            CommentModel.self, FootnoteModel.self, PoetryFormModel.self,
            StoryScene.self, Chapter.self, Character.self, Location.self,
            CustomAttribute.self, PlotElement.self,
            Act.self, ProseSection.self,
            PoetryCollection.self, Book.self,
            TextFileSectionLink.self, TextFileCollectionLink.self,
            SceneChapterLink.self, SceneActLink.self, SceneBookLink.self,
            ScenePlotElementLink.self, SceneCharacterLink.self,
            CharacterPlotElementLink.self, LocationPlotElementLink.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
    }
    
    override func tearDown() {
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Helpers
    
    private func makePoetryProject() -> Project {
        let project = Project(name: "Test Poetry", type: .poetry)
        modelContext.insert(project)
        return project
    }
    
    private func makeContentFolder(name: String, project: Project) -> Folder {
        let folder = Folder(name: name, project: project)
        modelContext.insert(folder)
        return folder
    }
    
    private func makeFile(name: String, folder: Folder, status: WorkflowStatus? = nil) -> TextFile {
        let file = TextFile(name: name, initialContent: "", parentFolder: folder)
        file.workflowStatus = status
        modelContext.insert(file)
        return file
    }
    
    // MARK: - Create Submission from Files
    
    func testCreateSubmissionAddsAllFiles() throws {
        let project = makePoetryProject()
        let folder = makeContentFolder(name: "Poems", project: project)
        let file1 = makeFile(name: "Poem A", folder: folder, status: .ready)
        let file2 = makeFile(name: "Poem B", folder: folder, status: .ready)
        try modelContext.save()
        
        // Create submission with files
        let submission = Submission(project: project, submittedDate: Date())
        submission.name = "My Submission"
        submission.isCollection = false
        modelContext.insert(submission)
        
        for file in [file1, file2] {
            let sf = SubmittedFile(
                submission: submission,
                textFile: file,
                version: file.currentVersion,
                status: .pending,
                project: project
            )
            modelContext.insert(sf)
        }
        try modelContext.save()
        
        XCTAssertEqual(submission.fileCount, 2)
        let fileNames = (submission.submittedFiles ?? []).compactMap { $0.textFile?.name }.sorted()
        XCTAssertEqual(fileNames, ["Poem A", "Poem B"])
    }
    
    // MARK: - Add Files to Existing Submission (No Duplicates)
    
    func testAddFilesToExistingSubmission_NoDuplicates() throws {
        let project = makePoetryProject()
        let folder = makeContentFolder(name: "Poems", project: project)
        let file1 = makeFile(name: "Poem A", folder: folder, status: .ready)
        let file2 = makeFile(name: "Poem B", folder: folder, status: .ready)
        try modelContext.save()
        
        // Create submission with file1
        let submission = Submission(project: project, submittedDate: Date())
        submission.name = "Existing Sub"
        submission.isCollection = false
        modelContext.insert(submission)
        
        let sf1 = SubmittedFile(
            submission: submission,
            textFile: file1,
            version: file1.currentVersion,
            status: .pending,
            project: project
        )
        modelContext.insert(sf1)
        try modelContext.save()
        
        XCTAssertEqual(submission.fileCount, 1)
        
        // Now add both files (file1 already exists, file2 is new)
        let existingFileIDs = Set((submission.submittedFiles ?? []).compactMap { $0.textFile?.id })
        for file in [file1, file2] where !existingFileIDs.contains(file.id) {
            let sf = SubmittedFile(
                submission: submission,
                textFile: file,
                version: file.currentVersion,
                status: .pending,
                project: project
            )
            modelContext.insert(sf)
        }
        try modelContext.save()
        
        XCTAssertEqual(submission.fileCount, 2, "Should have 2 files, not 3 (file1 not duplicated)")
    }
    
    // MARK: - Available Files from Content Folders by Workflow Status
    
    func testAvailableFilesUsesWorkflowStatus() throws {
        let project = makePoetryProject()
        let poemsFolder = makeContentFolder(name: "Poems", project: project)
        
        let readyFile1 = makeFile(name: "Ready A", folder: poemsFolder, status: .ready)
        let readyFile2 = makeFile(name: "Ready B", folder: poemsFolder, status: .ready)
        _ = makeFile(name: "Draft C", folder: poemsFolder, status: .draft)
        _ = makeFile(name: "SetAside D", folder: poemsFolder, status: .setAside)
        try modelContext.save()
        
        // Replicate the loadAvailableFiles logic
        let contentFolders = (project.folders ?? []).filter { FolderCapabilityService.isContentFolder($0) }
        let readyFiles = contentFolders.flatMap { folder in
            (folder.textFiles ?? []).filter { $0.workflowStatus == .ready }
        }
        
        XCTAssertEqual(readyFiles.count, 2)
        let names = readyFiles.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Ready A", "Ready B"])
        
        // Verify it does NOT include Draft/SetAside files
        XCTAssertFalse(readyFiles.contains(where: { $0.name == "Draft C" }))
        XCTAssertFalse(readyFiles.contains(where: { $0.name == "SetAside D" }))
    }
    
    func testAvailableFilesExcludesAlreadyAdded() throws {
        let project = makePoetryProject()
        let poemsFolder = makeContentFolder(name: "Poems", project: project)
        
        let readyFile1 = makeFile(name: "Ready A", folder: poemsFolder, status: .ready)
        let readyFile2 = makeFile(name: "Ready B", folder: poemsFolder, status: .ready)
        let readyFile3 = makeFile(name: "Ready C", folder: poemsFolder, status: .ready)
        try modelContext.save()
        
        // Create a submission (collection) with readyFile1 already added
        let submission = Submission(project: project, submittedDate: Date())
        submission.name = "My Collection"
        submission.isCollection = true
        modelContext.insert(submission)
        
        let sf = SubmittedFile(
            submission: submission,
            textFile: readyFile1,
            version: readyFile1.currentVersion,
            status: .pending,
            project: project
        )
        modelContext.insert(sf)
        try modelContext.save()
        
        // Replicate the loadAvailableFiles logic
        let contentFolders = (project.folders ?? []).filter { FolderCapabilityService.isContentFolder($0) }
        let readyFiles = contentFolders.flatMap { folder in
            (folder.textFiles ?? []).filter { $0.workflowStatus == .ready }
        }
        let alreadyAdded = Set((submission.submittedFiles ?? []).compactMap { $0.textFile?.id })
        let available = readyFiles.filter { !alreadyAdded.contains($0.id) }
        
        XCTAssertEqual(available.count, 2)
        let names = available.map { $0.name }.sorted()
        XCTAssertEqual(names, ["Ready B", "Ready C"])
    }
    
    func testAvailableFilesFromNonContentFolderReturnsEmpty() throws {
        let project = makePoetryProject()
        let researchFolder = makeContentFolder(name: "Research", project: project)
        _ = makeFile(name: "Note A", folder: researchFolder, status: .ready)
        try modelContext.save()
        
        // Only content folders should be searched
        let contentFolders = (project.folders ?? []).filter { FolderCapabilityService.isContentFolder($0) }
        let readyFiles = contentFolders.flatMap { folder in
            (folder.textFiles ?? []).filter { $0.workflowStatus == .ready }
        }
        
        XCTAssertTrue(readyFiles.isEmpty, "Research folder is not a content folder — files should not appear")
    }
}
