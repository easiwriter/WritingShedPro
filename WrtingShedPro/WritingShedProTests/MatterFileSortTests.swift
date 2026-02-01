//
//  MatterFileSortTests.swift
//  WritingShedProTests
//
//  Unit tests for Front Matter / Back Matter file sorting by userOrder
//  Tests the sorting behavior for matter folder files
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class MatterFileSortTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    var frontMatterFolder: Folder!
    var backMatterFolder: Folder!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
        
        testProject = Project(name: "Test Project", type: .prose)
        modelContext.insert(testProject)
        
        // Create Front Matter folder
        frontMatterFolder = Folder(name: "Front Matter", project: testProject)
        modelContext.insert(frontMatterFolder)
        
        // Create Back Matter folder
        backMatterFolder = Folder(name: "Back Matter", project: testProject)
        modelContext.insert(backMatterFolder)
        
        try? modelContext.save()
    }
    
    override func tearDown() {
        testProject = nil
        frontMatterFolder = nil
        backMatterFolder = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Helper
    
    private func createTextFile(name: String, folder: Folder, userOrder: Int?) -> TextFile {
        let file = TextFile(name: name, parentFolder: folder)
        file.userOrder = userOrder
        modelContext.insert(file)
        return file
    }
    
    // MARK: - UserOrder Sorting Tests
    
    func testFilesSortedByUserOrder() {
        // Create files with specific userOrder values
        let file1 = createTextFile(name: "Title Page", folder: frontMatterFolder, userOrder: 0)
        let file2 = createTextFile(name: "Dedication", folder: frontMatterFolder, userOrder: 2)
        let file3 = createTextFile(name: "Copyright", folder: frontMatterFolder, userOrder: 1)
        
        try? modelContext.save()
        
        let files = [file2, file3, file1] // Unsorted array
        let sorted = files.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        XCTAssertEqual(sorted[0].name, "Title Page")   // userOrder: 0
        XCTAssertEqual(sorted[1].name, "Copyright")    // userOrder: 1
        XCTAssertEqual(sorted[2].name, "Dedication")   // userOrder: 2
    }
    
    func testFilesSortedWithNilUserOrder() {
        // Files with nil userOrder should be treated as 0
        let file1 = createTextFile(name: "Title Page", folder: frontMatterFolder, userOrder: nil)
        let file2 = createTextFile(name: "Dedication", folder: frontMatterFolder, userOrder: 1)
        let file3 = createTextFile(name: "Copyright", folder: frontMatterFolder, userOrder: nil)
        
        try? modelContext.save()
        
        let files = [file2, file1, file3]
        let sorted = files.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        // Files with nil (treated as 0) should come before userOrder: 1
        XCTAssertEqual(sorted[2].name, "Dedication") // userOrder: 1 comes last
    }
    
    func testReorderingUpdatesUserOrder() {
        // Simulate what moveMatterFiles does
        var files = [
            createTextFile(name: "Title Page", folder: frontMatterFolder, userOrder: 0),
            createTextFile(name: "Copyright", folder: frontMatterFolder, userOrder: 1),
            createTextFile(name: "Dedication", folder: frontMatterFolder, userOrder: 2)
        ]
        
        try? modelContext.save()
        
        // Simulate moving Dedication (index 2) to position 1
        files.move(fromOffsets: IndexSet(integer: 2), toOffset: 1)
        
        // Update userOrder for all files (as done in moveMatterFiles)
        for (index, file) in files.enumerated() {
            file.userOrder = index
        }
        
        XCTAssertEqual(files[0].name, "Title Page")
        XCTAssertEqual(files[0].userOrder, 0)
        XCTAssertEqual(files[1].name, "Dedication")
        XCTAssertEqual(files[1].userOrder, 1)
        XCTAssertEqual(files[2].name, "Copyright")
        XCTAssertEqual(files[2].userOrder, 2)
    }
    
    // MARK: - Folder Type Tests
    
    func testFrontMatterFolderIdentification() {
        XCTAssertTrue(frontMatterFolder.isFrontMatterFolder)
        XCTAssertFalse(frontMatterFolder.isBackMatterFolder)
    }
    
    func testBackMatterFolderIdentification() {
        XCTAssertTrue(backMatterFolder.isBackMatterFolder)
        XCTAssertFalse(backMatterFolder.isFrontMatterFolder)
    }
    
    func testRegularFolderNotMatterFolder() {
        let regularFolder = Folder(name: "Poems", project: testProject)
        modelContext.insert(regularFolder)
        
        XCTAssertFalse(regularFolder.isFrontMatterFolder)
        XCTAssertFalse(regularFolder.isBackMatterFolder)
    }
    
    // MARK: - Back Matter Sorting Tests
    
    func testBackMatterFilesSortedByUserOrder() {
        let file1 = createTextFile(name: "Endnotes", folder: backMatterFolder, userOrder: 0)
        let file2 = createTextFile(name: "Glossary", folder: backMatterFolder, userOrder: 1)
        let file3 = createTextFile(name: "Index", folder: backMatterFolder, userOrder: 2)
        
        try? modelContext.save()
        
        let files = [file3, file1, file2] // Unsorted
        let sorted = files.sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        XCTAssertEqual(sorted[0].name, "Endnotes")
        XCTAssertEqual(sorted[1].name, "Glossary")
        XCTAssertEqual(sorted[2].name, "Index")
    }
}
