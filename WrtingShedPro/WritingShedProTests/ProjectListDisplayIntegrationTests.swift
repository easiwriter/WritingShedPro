import XCTest
@testable import Writing_Shed_Pro

final class ProjectListDisplayIntegrationTests: XCTestCase {
    
    func testProjectListDisplaysMultipleProjects() {
        // Arrange
        let projects = [
            Project(name: "Novel", type: .prose),
            Project(name: "Sonnet", type: .poetry),
            Project(name: "Play", type: .drama)
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
            Project(name: "Zebra Project", type: .prose),
            Project(name: "Alpha Project", type: .poetry),
            Project(name: "Beta Project", type: .drama)
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
            Project(name: "Future", type: .prose, creationDate: futureDate),
            Project(name: "Old", type: .poetry, creationDate: oldDate),
            Project(name: "Recent", type: .drama, creationDate: recentDate)
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
            Project(name: "Novel", type: .prose),
            Project(name: "Haiku", type: .poetry),
            Project(name: "Screenplay", type: .drama)
        ]
        
        // Assert
        XCTAssertEqual(projects[0].projectType, .prose)
        XCTAssertEqual(projects[1].projectType, .poetry)
        XCTAssertEqual(projects[2].projectType, .drama)
    }
    
    func testProjectListHandlesMixedCaseNames() {
        // Arrange
        let projects = [
            Project(name: "UPPERCASE", type: .prose),
            Project(name: "lowercase", type: .poetry),
            Project(name: "MixedCase", type: .drama)
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
        let project = Project(name: "My Project", type: .prose, details: details)
        
        // Assert
        XCTAssertEqual(project.details, details)
        XCTAssertNotNil(project.id)
        XCTAssertNotNil(project.creationDate)
    }
}
