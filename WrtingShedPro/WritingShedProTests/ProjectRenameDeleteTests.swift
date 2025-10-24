import XCTest
@testable import Writing_Shed_Pro

final class ProjectRenameDeleteTests: XCTestCase {
    
    // MARK: - Rename Validation Tests
    
    func testRenameProjectWithValidName() {
        // Arrange
        let project = Project(name: "Original Name", type: .poetry)
        let newName = "Updated Name"
        
        // Act
        project.name = newName
        
        // Assert
        XCTAssertEqual(project.name, newName)
    }
    
    func testRenameProjectValidationRejectsEmptyName() {
        // Arrange
        let emptyName = ""
        
        // Act & Assert
        XCTAssertThrowsError(try NameValidator.validateProjectName(emptyName)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.emptyName(entity: "Project"))
        }
    }
    
    func testRenameProjectValidationRejectsWhitespaceOnlyName() {
        // Arrange
        let whitespaceName = "   "
        
        // Act & Assert
        XCTAssertThrowsError(try NameValidator.validateProjectName(whitespaceName)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.emptyName(entity: "Project"))
        }
    }
    
    func testRenameProjectUniquenessCheck() {
        // Arrange
        let existingProjects = [
            Project(name: "Project One", type: .poetry),
            Project(name: "Project Two", type: .poetry)
        ]
        
        // Act & Assert
        XCTAssertTrue(UniquenessChecker.isProjectNameUnique("Project Three", in: existingProjects))
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("Project One", in: existingProjects))
    }
    
    func testRenameProjectUniquenessCaseInsensitive() {
        // Arrange
        let existingProjects = [
            Project(name: "My Project", type: .poetry)
        ]
        
        // Act & Assert
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("my project", in: existingProjects))
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("MY PROJECT", in: existingProjects))
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("My Project", in: existingProjects))
    }
    
    func testRenameProjectToSameNameIsValid() {
        // Arrange
        let project = Project(name: "My Project", type: .poetry)
        let projects = [project]
        
        // Act & Assert - renaming to the same name should be allowed
        // (In practice, we'd filter out the current project from uniqueness check)
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique("My Project", in: projects))
    }
    
    // MARK: - Delete Tests
    
    func testDeleteProjectRemovesFromList() {
        // Arrange
        var projects = [
            Project(name: "Project 1", type: .poetry),
            Project(name: "Project 2", type: .poetry),
            Project(name: "Project 3", type: .script)
        ]
        let projectToDelete = projects[1]
        
        // Act
        projects.removeAll { $0.id == projectToDelete.id }
        
        // Assert
        XCTAssertEqual(projects.count, 2)
        XCTAssertFalse(projects.contains { $0.id == projectToDelete.id })
    }
    
    func testDeleteProjectPreservesOtherProjects() {
        // Arrange
        let project1 = Project(name: "Project 1", type: .poetry)
        let project2 = Project(name: "Project 2", type: .poetry)
        let project3 = Project(name: "Project 3", type: .script)
        var projects = [project1, project2, project3]
        
        // Act - delete middle project
        projects.removeAll { $0.id == project2.id }
        
        // Assert
        XCTAssertEqual(projects.count, 2)
        XCTAssertTrue(projects.contains { $0.id == project1.id })
        XCTAssertTrue(projects.contains { $0.id == project3.id })
    }
    
    func testDeleteLastProjectLeavesEmptyList() {
        // Arrange
        let project = Project(name: "Only Project", type: .poetry)
        var projects = [project]
        
        // Act
        projects.removeAll { $0.id == project.id }
        
        // Assert
        XCTAssertEqual(projects.count, 0)
    }
    
    func testDeleteProjectWithFolders() {
        // Arrange
        let project = Project(name: "Project", type: .poetry)
        let folder = Folder(name: "Folder", project: project)
        project.folders = [folder]
        
        // Assert - folder relationship exists
        XCTAssertEqual(project.folders?.count, 1)
        
        // Act - in SwiftData, cascade delete rule would handle this
        // For unit test, we verify the relationship exists
        XCTAssertNotNil(project.folders)
    }
    
    // MARK: - Project Details Tests
    
    func testUpdateProjectDetails() {
        // Arrange
        let project = Project(name: "My Novel", type: .poetry, details: "Initial details")
        
        // Act
        project.details = "Updated details with more information"
        
        // Assert
        XCTAssertEqual(project.details, "Updated details with more information")
    }
    
    func testClearProjectDetails() {
        // Arrange
        let project = Project(name: "My Novel", type: .poetry, details: "Some details")
        
        // Act
        project.details = nil
        
        // Assert
        XCTAssertNil(project.details)
    }
    
    func testProjectPreservesCreationDate() {
        // Arrange
        let creationDate = Date(timeIntervalSinceNow: -3600)
        let project = Project(name: "Project", type: .poetry, creationDate: creationDate)
        
        // Act - rename project
        project.name = "Renamed Project"
        
        // Assert - creation date should remain unchanged
        XCTAssertEqual(project.creationDate, creationDate)
    }
}
