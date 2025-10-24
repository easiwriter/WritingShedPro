import XCTest
@testable import Writing_Shed_Pro

final class ProjectRenameDeleteIntegrationTests: XCTestCase {
    
    // MARK: - Rename Integration Tests
    
    func testRenameProjectEndToEnd() {
        // Arrange
        let project = Project(name: "Original Name", type: .prose)
        let newName = "New Name"
        let projects = [project]
        
        // Act - validate new name
        XCTAssertNoThrow(try NameValidator.validateProjectName(newName))
        
        // Check uniqueness (excluding current project in real scenario)
        let otherProjects = projects.filter { $0.id != project.id }
        XCTAssertTrue(UniquenessChecker.isProjectNameUnique(newName, in: otherProjects))
        
        // Perform rename
        project.name = newName
        
        // Assert
        XCTAssertEqual(project.name, newName)
    }
    
    func testRenameProjectWithValidationFailure() {
        // Arrange
        let project = Project(name: "Valid Name", type: .prose)
        let invalidName = "  "
        
        // Act & Assert - validation should fail
        XCTAssertThrowsError(try NameValidator.validateProjectName(invalidName)) { error in
            XCTAssertEqual(error as? ValidationError, ValidationError.emptyName(entity: "Project"))
        }
        
        // Original name should be preserved
        XCTAssertEqual(project.name, "Valid Name")
    }
    
    func testRenameProjectWithDuplicateNameFailure() {
        // Arrange
        let project1 = Project(name: "Project 1", type: .prose)
        let project2 = Project(name: "Project 2", type: .poetry)
        let projects = [project1, project2]
        
        // Act - try to rename project2 to project1's name
        let desiredName = "Project 1"
        let otherProjects = projects.filter { $0.id != project2.id }
        
        // Assert - uniqueness check should fail
        XCTAssertFalse(UniquenessChecker.isProjectNameUnique(desiredName, in: otherProjects))
        
        // Original name should be preserved
        XCTAssertEqual(project2.name, "Project 2")
    }
    
    func testRenameProjectToSameName() {
        // Arrange
        let project = Project(name: "My Project", type: .prose)
        let originalName = project.name
        let projects = [project]
        
        // Act - rename to same name
        let otherProjects = projects.filter { $0.id != project.id }
        XCTAssertTrue(UniquenessChecker.isProjectNameUnique(originalName ?? "", in: otherProjects))
        
        project.name = originalName
        
        // Assert
        XCTAssertEqual(project.name, originalName)
    }
    
    func testRenameProjectPreservesOtherProperties() {
        // Arrange
        let creationDate = Date(timeIntervalSinceNow: -3600)
        let details = "Project details"
        let project = Project(name: "Original", type: .drama, creationDate: creationDate, details: details)
        let originalId = project.id
        
        // Act
        project.name = "Renamed"
        
        // Assert - all other properties preserved
        XCTAssertEqual(project.name, "Renamed")
        XCTAssertEqual(project.id, originalId)
        XCTAssertEqual(project.projectType, .drama)
        XCTAssertEqual(project.creationDate, creationDate)
        XCTAssertEqual(project.details, details)
    }
    
    // MARK: - Delete Integration Tests
    
    func testDeleteProjectEndToEnd() {
        // Arrange
        var projects = [
            Project(name: "Keep 1", type: .prose),
            Project(name: "Delete Me", type: .poetry),
            Project(name: "Keep 2", type: .drama)
        ]
        let projectToDelete = projects[1]
        let initialCount = projects.count
        
        // Act
        projects.removeAll { $0.id == projectToDelete.id }
        
        // Assert
        XCTAssertEqual(projects.count, initialCount - 1)
        XCTAssertFalse(projects.contains { $0.id == projectToDelete.id })
        XCTAssertTrue(projects.contains { $0.name == "Keep 1" })
        XCTAssertTrue(projects.contains { $0.name == "Keep 2" })
    }
    
    func testDeleteProjectWithConfirmation() {
        // Arrange
        let project = Project(name: "To Delete", type: .prose)
        var projects = [project]
        var userConfirmed = false
        
        // Act - simulate confirmation dialog
        userConfirmed = true
        
        if userConfirmed {
            projects.removeAll { $0.id == project.id }
        }
        
        // Assert
        XCTAssertEqual(projects.count, 0)
    }
    
    func testCancelDeletePreservesProject() {
        // Arrange
        let project = Project(name: "To Keep", type: .prose)
        var projects = [project]
        
        // Act - simulate user canceling delete (userConfirmed = false)
        let userConfirmed = false
        
        // Only delete if user confirmed (they didn't, so this won't execute)
        if userConfirmed {
            projects.removeAll { $0.id == project.id }
        }
        
        // Assert - project should still exist since delete was cancelled
        XCTAssertEqual(projects.count, 1)
        XCTAssertEqual(projects[0].name, "To Keep")
    }
    
    func testDeleteProjectFromSortedList() {
        // Arrange
        var projects = [
            Project(name: "Zebra", type: .prose),
            Project(name: "Alpha", type: .poetry),
            Project(name: "Beta", type: .drama)
        ]
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        let projectToDelete = sorted[1] // Beta
        
        // Act
        projects.removeAll { $0.id == projectToDelete.id }
        let newSorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(newSorted.count, 2)
        XCTAssertEqual(newSorted[0].name, "Alpha")
        XCTAssertEqual(newSorted[1].name, "Zebra")
    }
    
    // MARK: - Project Details Integration Tests
    
    func testViewAndEditProjectDetails() {
        // Arrange
        let project = Project(name: "My Novel", type: .prose, details: "Initial outline")
        
        // Act - view details
        let initialDetails = project.details
        XCTAssertEqual(initialDetails, "Initial outline")
        
        // Edit details
        project.details = "Updated outline with chapter breakdown"
        
        // Assert
        XCTAssertEqual(project.details, "Updated outline with chapter breakdown")
    }
    
    func testAddDetailsToProjectWithoutDetails() {
        // Arrange
        let project = Project(name: "My Novel", type: .prose)
        XCTAssertNil(project.details)
        
        // Act
        project.details = "Newly added details"
        
        // Assert
        XCTAssertEqual(project.details, "Newly added details")
    }
    
    func testClearProjectDetails() {
        // Arrange
        let project = Project(name: "My Novel", type: .prose, details: "Some details")
        
        // Act
        project.details = ""
        
        // Assert
        XCTAssertEqual(project.details, "")
    }
    
    func testEditMultipleProjectProperties() {
        // Arrange
        let project = Project(name: "Original", type: .prose)
        
        // Act - edit name and details
        project.name = "Updated Name"
        project.details = "New details"
        
        // Assert
        XCTAssertEqual(project.name, "Updated Name")
        XCTAssertEqual(project.details, "New details")
        XCTAssertEqual(project.projectType, .prose) // Type unchanged
    }
    
    // MARK: - Combined Workflow Tests
    
    func testCompleteProjectLifecycle() {
        // Arrange - create project
        var projects: [Project] = []
        let newProject = Project(name: "My Project", type: .prose, details: "Initial details")
        projects.append(newProject)
        
        XCTAssertEqual(projects.count, 1)
        
        // Act - rename
        newProject.name = "Renamed Project"
        XCTAssertEqual(newProject.name, "Renamed Project")
        
        // Update details
        newProject.details = "Updated details"
        XCTAssertEqual(newProject.details, "Updated details")
        
        // Delete
        projects.removeAll { $0.id == newProject.id }
        
        // Assert
        XCTAssertEqual(projects.count, 0)
    }
}
