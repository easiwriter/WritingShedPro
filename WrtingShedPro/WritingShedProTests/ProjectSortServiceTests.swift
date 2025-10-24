import XCTest
@testable import Writing_Shed_Pro

final class ProjectSortServiceTests: XCTestCase {
    
    func testSortByNameAscending() {
        // Arrange
        let projects = [
            Project(name: "Zebra", type: .prose),
            Project(name: "Alpha", type: .poetry),
            Project(name: "Beta", type: .drama)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(sorted[0].name ?? "", "Alpha")
        XCTAssertEqual(sorted[1].name ?? "", "Beta")
        XCTAssertEqual(sorted[2].name ?? "", "Zebra")
    }
    
    func testSortByNameCaseInsensitive() {
        // Arrange
        let projects = [
            Project(name: "zebra", type: .prose),
            Project(name: "ALPHA", type: .poetry),
            Project(name: "BeTa", type: .drama)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(sorted[0].name?.lowercased() ?? "", "alpha")
        XCTAssertEqual(sorted[1].name?.lowercased() ?? "", "beta")
        XCTAssertEqual(sorted[2].name?.lowercased() ?? "", "zebra")
    }
    
    func testSortByCreationDate() {
        // Arrange
        let now = Date()
        let yesterday = Date(timeIntervalSinceNow: -86400)
        let tomorrow = Date(timeIntervalSinceNow: 86400)
        
        let projects = [
            Project(name: "Future", type: .prose, creationDate: tomorrow),
            Project(name: "Today", type: .poetry, creationDate: now),
            Project(name: "Yesterday", type: .drama, creationDate: yesterday)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byCreationDate)
        
        // Assert
        XCTAssertEqual(sorted[0].name ?? "", "Yesterday")
        XCTAssertEqual(sorted[1].name ?? "", "Today")
        XCTAssertEqual(sorted[2].name ?? "", "Future")
    }
    
    func testSortEmptyList() {
        // Arrange
        let projects: [Project] = []
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(sorted.count, 0)
    }
    
    func testSortSingleProject() {
        // Arrange
        let projects = [Project(name: "Single", type: .prose)]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byName)
        
        // Assert
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted[0].name ?? "", "Single")
    }
    
    func testSortByUserOrder() {
        // Arrange
        let projects = [
            Project(name: "First", type: .prose, userOrder: 2),
            Project(name: "Second", type: .poetry, userOrder: 0),
            Project(name: "Third", type: .drama, userOrder: 1)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byUserOrder)
        
        // Assert
        XCTAssertEqual(sorted[0].name ?? "", "Second") // userOrder: 0
        XCTAssertEqual(sorted[1].name ?? "", "Third")  // userOrder: 1
        XCTAssertEqual(sorted[2].name ?? "", "First")  // userOrder: 2
    }
    
    func testSortByUserOrderWithNilValues() {
        // Arrange
        let projects = [
            Project(name: "HasOrder", type: .prose, userOrder: 1),
            Project(name: "NoOrder1", type: .poetry, userOrder: nil),
            Project(name: "NoOrder2", type: .drama, userOrder: nil)
        ]
        
        // Act
        let sorted = ProjectSortService.sortProjects(projects, by: .byUserOrder)
        
        // Assert
        XCTAssertEqual(sorted[0].name ?? "", "HasOrder") // userOrder: 1
        // Projects with nil userOrder should come after those with order
        XCTAssertTrue(sorted[1].name == "NoOrder1" || sorted[1].name == "NoOrder2")
        XCTAssertTrue(sorted[2].name == "NoOrder1" || sorted[2].name == "NoOrder2")
    }
    
    func testUpdateUserOrder() {
        // Arrange
        var projects = [
            Project(name: "First", type: .prose, userOrder: 0),
            Project(name: "Second", type: .poetry, userOrder: 1),
            Project(name: "Third", type: .drama, userOrder: 2)
        ]
        let movedOffsets = IndexSet([0]) // Move "First" project
        let destination = 2 // Move to position 2 (between Second and Third)
        
        // Act
        let updated = ProjectSortService.updateUserOrder(
            for: projects,
            movedFromOffsets: movedOffsets,
            toOffset: destination
        )
        
        // Assert
        XCTAssertEqual(updated[0].name ?? "", "Second") // Now at position 0
        XCTAssertEqual(updated[0].userOrder, 0)
        XCTAssertEqual(updated[1].name ?? "", "First")  // Moved to position 1
        XCTAssertEqual(updated[1].userOrder, 1)
        XCTAssertEqual(updated[2].name ?? "", "Third")  // Now at position 2
        XCTAssertEqual(updated[2].userOrder, 2)
    }
}
