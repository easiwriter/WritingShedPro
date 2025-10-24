import XCTest
@testable import Writing_Shed_Pro

final class UniquenessCheckerTests: XCTestCase {
    
    func testIsProjectNameUniqueMissingReturnsTrue() {
        let projects: [Project] = []
        XCTAssertTrue(UniquenessChecker.isProjectNameUnique("New Project", in: projects))
    }
    
    func testIsProjectNameUniqueWithDifferentNameReturnsTrue() {
        let project = Project(name: "Existing Project", type: .poetry)
        let projects = [project]
        XCTAssertTrue(UniquenessChecker.isProjectNameUnique("New Project", in: projects))
    }
    
    func testIsProjectNameUniqueDuplicateReturnsFalse() {
        let project = Project(name: "My Project", type: .poetry)
        let projects = [project]
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("My Project", in: projects))
    }
    
    func testIsProjectNameUniqueCaseInsensitive() {
        let project = Project(name: "My Project", type: .poetry)
        let projects = [project]
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("my project", in: projects))
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("MY PROJECT", in: projects))
    }
    
    func testIsFolderNameUniqueMissingReturnsTrue() {
        let project = Project(name: "Project", type: .poetry)
        let folder = Folder(name: "Parent", project: project)
        XCTAssertTrue(UniquenessChecker.isFolderNameUnique("New Folder", in: folder))
    }
    
    func testIsFolderNameUniqueDuplicateReturnsFalse() {
        let project = Project(name: "Project", type: .poetry)
        let parentFolder = Folder(name: "Parent", project: project)
        let childFolder = Folder(name: "Child", project: project, parentFolder: parentFolder)
        if parentFolder.folders == nil {
            parentFolder.folders = []
        }
        parentFolder.folders?.append(childFolder)
        
        XCTAssertFalse(UniquenessChecker.isFolderNameUnique("Child", in: parentFolder))
    }
    
    func testIsFileNameUniqueMissingReturnsTrue() {
        let project = Project(name: "Project", type: .poetry)
        let folder = Folder(name: "Folder", project: project)
        XCTAssertTrue(UniquenessChecker.isFileNameUnique("newfile.txt", in: folder))
    }
    
    func testIsFileNameUniqueDuplicateReturnsFalse() {
        let project = Project(name: "Project", type: .poetry)
        let folder = Folder(name: "Folder", project: project)
        let file = File(name: "chapter.txt")
        file.parentFolder = folder
        if folder.files == nil {
            folder.files = []
        }
        folder.files?.append(file)
        
        XCTAssertFalse(UniquenessChecker.isFileNameUnique("chapter.txt", in: folder))
    }
}
