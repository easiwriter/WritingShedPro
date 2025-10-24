import XCTest
@testable import Writing_Shed_Pro

final class ProjectCreationIntegrationTests: XCTestCase {
    
    func testCreateProjectInMemory() {
        // Arrange
        let projectName = "My First Project"
        let projectType = ProjectType.prose
        
        // Act
        let project = Project(name: projectName, type: projectType)
        
        // Assert
        XCTAssertEqual(project.name, projectName)
        XCTAssertEqual(project.projectType, projectType)
        XCTAssertNotNil(project.id)
    }
    
    func testCreateMultipleProjectsInMemory() {
        // Arrange
        let projectNames = ["Project A", "Project B", "Project C"]
        
        // Act
        let projects = projectNames.map { Project(name: $0, type: .prose) }
        
        // Assert
        XCTAssertEqual(projects.count, 3)
        XCTAssertEqual(projects[0].name, "Project A")
        XCTAssertEqual(projects[1].name, "Project B")
        XCTAssertEqual(projects[2].name, "Project C")
    }
    
    func testCreateProjectWithDetails() {
        // Arrange
        let projectName = "Novel Project"
        let details = "A sci-fi novel set in the future"
        
        // Act
        let project = Project(name: projectName, type: .prose, details: details)
        
        // Assert
        XCTAssertEqual(project.name, projectName)
        XCTAssertEqual(project.details, details)
    }
    
    func testCreateProjectWithDifferentTypes() {
        // Arrange
        let types: [ProjectType] = [.prose, .poetry, .drama]
        
        // Act
        let projects = types.enumerated().map { (index, type) in
            Project(name: "Project \(index)", type: type)
        }
        
        // Assert
        XCTAssertEqual(projects.count, 3)
        XCTAssertEqual(projects[0].projectType, .prose)
        XCTAssertEqual(projects[1].projectType, .poetry)
        XCTAssertEqual(projects[2].projectType, .drama)
    }
    
    func testRenameProjectInMemory() {
        // Arrange
        let project = Project(name: "Original Name", type: .prose)
        
        // Act
        project.name = "New Name"
        
        // Assert
        XCTAssertEqual(project.name, "New Name")
    }
    
    func testUpdateProjectDetails() {
        // Arrange
        let project = Project(name: "My Project", type: .prose)
        
        // Act
        project.details = "New details"
        
        // Assert
        XCTAssertEqual(project.details, "New details")
    }
}
