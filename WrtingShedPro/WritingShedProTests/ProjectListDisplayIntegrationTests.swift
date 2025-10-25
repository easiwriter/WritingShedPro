import XCTest
@testable import Writing_Shed_Pro

final class ProjectListDisplayIntegrationTests: XCTestCase {
    
    func testProjectListDisplaysMultipleProjects() {
        // Arrange
        let projects = [
            Project(name: "Novel", type: .blank),
            Project(name: "Sonnet", type: .poetry),
            Project(name: "Play", type: .script)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].name ?? "", "Novel")
        XCTAssertEqual(sorted[1].name ?? "", "Play")
        XCTAssertEqual(sorted[2].name ?? "", "Sonnet")
    }
    
    func testProjectListSortsByNameCorrectly() {
        // Arrange
        let projects = [
            Project(name: "Zebra Project", type: .blank),
            Project(name: "Alpha Project", type: .poetry),
            Project(name: "Beta Project", type: .script)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(sorted[0].name ?? "", "Alpha Project")
        XCTAssertEqual(sorted[1].name ?? "", "Beta Project")
        XCTAssertEqual(sorted[2].name ?? "", "Zebra Project")
    }
    
    func testProjectListSortsByCreationDateCorrectly() {
        // Arrange
        let oldDate = Date(timeIntervalSinceNow: -86400)
        let recentDate = Date(timeIntervalSinceNow: -3600)
        let futureDate = Date(timeIntervalSinceNow: 3600)
        
        let projects = [
            Project(name: "Future", type: .blank, creationDate: futureDate),
            Project(name: "Old", type: .poetry, creationDate: oldDate),
            Project(name: "Recent", type: .script, creationDate: recentDate)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byCreationDate)
        
        // Assert
        XCTAssertEqual(sorted[0].name ?? "", "Old")
        XCTAssertEqual(sorted[1].name ?? "", "Recent")
        XCTAssertEqual(sorted[2].name ?? "", "Future")
    }
    
    func testProjectListDisplaysEmptyStateWhenNoProjects() {
        // Arrange
        let projects: [Project] = []
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(sorted.count, 0)
    }
    
    func testProjectListDisplaysProjectTypes() {
        // Arrange
        let projects = [
            Project(name: "Novel", type: .blank),
            Project(name: "Haiku", type: .poetry),
            Project(name: "Screenplay", type: .script)
        ]
        
        // Assert
        XCTAssertEqual(projects[0].projectType, .blank)
        XCTAssertEqual(projects[1].projectType, .poetry)
        XCTAssertEqual(projects[2].projectType, .script)
    }
    
    func testProjectListHandlesMixedCaseNames() {
        // Arrange
        let projects = [
            Project(name: "UPPERCASE", type: .blank),
            Project(name: "lowercase", type: .poetry),
            Project(name: "MixedCase", type: .script)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert - should be case-insensitive alphabetical order
        XCTAssertEqual(sorted[0].name?.lowercased() ?? "", "lowercase")
        XCTAssertEqual(sorted[1].name?.lowercased() ?? "", "mixedcase")
        XCTAssertEqual(sorted[2].name?.lowercased() ?? "", "uppercase")
    }
    
    func testProjectListPreservesProjectDetails() {
        // Arrange
        let details = "A detailed description of my project"
        let project = Project(name: "My Project", type: .blank, details: details)
        
        // Assert
        XCTAssertEqual(project.details, details)
        XCTAssertNotNil(project.id)
        XCTAssertNotNil(project.creationDate)
    }
}
