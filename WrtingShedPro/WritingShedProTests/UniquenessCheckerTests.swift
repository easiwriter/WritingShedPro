import XCTest
@testable import Writing_Shed_Pro

final class UniquenessCheckerTests: XCTestCase {
    
    func testIsProjectNameUniqueMissingReturnsTrue() {
        let projects: [Project] = []
        XCTAssertTrue(UniquenessChecker.isProjectNameUnique("New Project", in: projects))
    }
    
    func testIsProjectNameUniqueWithDifferentNameReturnsTrue() {
        let project = Project(name: "Existing Project", type: .blank)
        let projects = [project]
        XCTAssertTrue(UniquenessChecker.isProjectNameUnique("New Project", in: projects))
    }
    
    func testIsProjectNameUniqueDuplicateReturnsFalse() {
        let project = Project(name: "My Project", type: .blank)
        let projects = [project]
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("My Project", in: projects))
    }
    
    func testIsProjectNameUniqueCaseInsensitive() {
        let project = Project(name: "My Project", type: .blank)
        let projects = [project]
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("my project", in: projects))
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("MY PROJECT", in: projects))
    }
    
    func testIsFolderNameUniqueMissingReturnsTrue() {
        let project = Project(name: "Project", type: .blank)
        XCTAssertTrue(UniquenessChecker.isFolderNameUnique("New Folder", in: project))
    }
    
    func testIsFolderNameUniqueDuplicateReturnsFalse() {
        let project = Project(name: "Project", type: .blank)
        let existingFolder = Folder(name: "Existing Folder", project: project)
        project.folders = [existingFolder]
        
        XCTAssertFalse(UniquenessChecker.isFolderNameUnique("Existing Folder", in: project))
    }
    
    func testIsFolderNameUniqueInParentFolder() {
        let project = Project(name: "Project", type: .blank)
        let parentFolder = Folder(name: "Parent", project: project)
        let childFolder = Folder(name: "Child", project: project, parentFolder: parentFolder)
        parentFolder.folders = [childFolder]
        project.folders = [parentFolder] // Set up the project hierarchy
        
        // Should be able to use "Child" at root level even though it exists in parent
        XCTAssertTrue(UniquenessChecker.isFolderNameUnique("Child", in: project, parentFolder: nil))
        
        // Should not be able to use "Child" within parent folder
        XCTAssertFalse(UniquenessChecker.isFolderNameUnique("Child", in: project, parentFolder: parentFolder))
        
        // Should be able to use "New" within parent folder
        XCTAssertTrue(UniquenessChecker.isFolderNameUnique("New", in: project, parentFolder: parentFolder))
    }
    
    func testIsFolderNameUniqueExcludingFolder() {
        let project = Project(name: "Project", type: .blank)
        let folder1 = Folder(name: "Folder One", project: project)
        let folder2 = Folder(name: "Folder Two", project: project)
        project.folders = [folder1, folder2]
        
        // When renaming folder2, it should be able to keep its own name
        XCTAssertTrue(UniquenessChecker.isFolderNameUnique("Folder Two", in: project, parentFolder: nil, excludingFolder: folder2))
        
        // But should not be able to take folder1's name
        XCTAssertFalse(UniquenessChecker.isFolderNameUnique("Folder One", in: project, parentFolder: nil, excludingFolder: folder2))
        
        // Should be able to use a new name
        XCTAssertTrue(UniquenessChecker.isFolderNameUnique("Folder Three", in: project, parentFolder: nil, excludingFolder: folder2))
    }
    
    func testIsFileNameUniqueMissingReturnsTrue() {
        let project = Project(name: "Project", type: .blank)
        let folder = Folder(name: "Folder", project: project)
        XCTAssertTrue(UniquenessChecker.isFileNameUnique("newfile.txt", in: folder))
    }
    
    func testIsFileNameUniqueDuplicateReturnsFalse() {
        let project = Project(name: "Project", type: .blank)
        let folder = Folder(name: "Folder", project: project)
        let file = TextFile(name: "chapter.txt", initialContent: "", parentFolder: folder)
        
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("chapter.txt", in: folder))
    }
    
    func testIsFileNameUniqueAfterDeletionReturnsFalse() {
        let project = Project(name: "Project", type: .blank)
        let folder = Folder(name: "Folder", project: project)
        let file = TextFile(name: "Test", initialContent: "", parentFolder: folder)
        folder.textFiles = [file]
        project.folders = [folder]
        
        // Create a trash item for the deleted file
        let trashItem = TrashItem(textFile: file, originalFolder: folder, project: project)
        project.trashedItems = [trashItem]
        
        // After deletion (file in trash), should not be able to create a new file with same name
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("Test", in: folder),
                       "Should reject creating new file with deleted file's name")
    }
}
