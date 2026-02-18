//
//  ContributorEntryTests.swift
//  WritingShedProTests
//
//  Unit tests for ContributorEntry model
//  Tests display name formatting, sorting, and model behavior
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

final class ContributorEntryTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var testProject: Project!
    
    override func setUp() {
        super.setUp()
        let schema = Schema([
            Project.self, Folder.self, TextFile.self, Version.self,
            ContributorEntry.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        modelContainer = try! ModelContainer(for: schema, configurations: config)
        modelContext = ModelContext(modelContainer)
        
        testProject = Project(name: "Test Project", type: .prose)
        modelContext.insert(testProject)
    }
    
    override func tearDown() {
        testProject = nil
        modelContainer = nil
        modelContext = nil
        super.tearDown()
    }
    
    // MARK: - Display Name Tests
    
    func testDisplayNameWithBothNames() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "Jane",
            surname: "Austen"
        )
        
        XCTAssertEqual(contributor.displayName, "Austen, Jane")
    }
    
    func testDisplayNameWithOnlySurname() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "",
            surname: "Shakespeare"
        )
        
        XCTAssertEqual(contributor.displayName, "Shakespeare")
    }
    
    func testDisplayNameWithOnlyFirstName() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "Homer",
            surname: ""
        )
        
        XCTAssertEqual(contributor.displayName, "Homer")
    }
    
    func testDisplayNameWithNoNames() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "",
            surname: ""
        )
        
        // Should return localized "Unnamed Contributor"
        XCTAssertFalse(contributor.displayName.isEmpty)
    }
    
    // MARK: - Full Name Tests
    
    func testFullNameWithBothNames() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "Jane",
            surname: "Austen"
        )
        
        XCTAssertEqual(contributor.fullName, "Jane Austen")
    }
    
    func testFullNameWithOnlySurname() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "",
            surname: "Shakespeare"
        )
        
        XCTAssertEqual(contributor.fullName, "Shakespeare")
    }
    
    func testFullNameWithOnlyFirstName() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "Homer",
            surname: ""
        )
        
        XCTAssertEqual(contributor.fullName, "Homer")
    }
    
    // MARK: - Comparable Tests (Sorting)
    
    func testSortingBySurnameFirst() {
        let contributors = [
            ContributorEntry(project: testProject, firstName: "Jane", surname: "Austen"),
            ContributorEntry(project: testProject, firstName: "Charles", surname: "Dickens"),
            ContributorEntry(project: testProject, firstName: "Emily", surname: "Bronte")
        ]
        
        let sorted = contributors.sorted()
        
        XCTAssertEqual(sorted[0].surname, "Austen")
        XCTAssertEqual(sorted[1].surname, "Bronte")
        XCTAssertEqual(sorted[2].surname, "Dickens")
    }
    
    func testSortingByFirstNameWhenSurnamesMatch() {
        let contributors = [
            ContributorEntry(project: testProject, firstName: "Emily", surname: "Bronte"),
            ContributorEntry(project: testProject, firstName: "Anne", surname: "Bronte"),
            ContributorEntry(project: testProject, firstName: "Charlotte", surname: "Bronte")
        ]
        
        let sorted = contributors.sorted()
        
        XCTAssertEqual(sorted[0].firstName, "Anne")
        XCTAssertEqual(sorted[1].firstName, "Charlotte")
        XCTAssertEqual(sorted[2].firstName, "Emily")
    }
    
    func testSortingIsCaseInsensitive() {
        let contributors = [
            ContributorEntry(project: testProject, firstName: "Jane", surname: "AUSTEN"),
            ContributorEntry(project: testProject, firstName: "Charles", surname: "dickens"),
            ContributorEntry(project: testProject, firstName: "Emily", surname: "Bronte")
        ]
        
        let sorted = contributors.sorted()
        
        XCTAssertEqual(sorted[0].surname, "AUSTEN")
        XCTAssertEqual(sorted[1].surname, "Bronte")
        XCTAssertEqual(sorted[2].surname, "dickens")
    }
    
    // MARK: - Update Tests
    
    func testUpdateModifiesFields() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "Original",
            surname: "Name",
            biography: "Original bio"
        )
        
        let originalModifiedAt = contributor.modifiedAt
        
        // Small delay to ensure modifiedAt changes
        Thread.sleep(forTimeInterval: 0.01)
        
        contributor.update(name: "New Updated", biography: "New bio")
        
        XCTAssertEqual(contributor.displayName, "New Updated")
        XCTAssertEqual(contributor.biography, "New bio")
        XCTAssertGreaterThan(contributor.modifiedAt, originalModifiedAt)
    }
    
    // MARK: - Initialization Tests
    
    func testDefaultInitialization() {
        let contributor = ContributorEntry()
        
        XCTAssertFalse(contributor.id.uuidString.isEmpty)
        XCTAssertEqual(contributor.firstName, "")
        XCTAssertEqual(contributor.surname, "")
        XCTAssertEqual(contributor.biography, "")
        XCTAssertEqual(contributor.userOrder, 0)
        XCTAssertNotNil(contributor.createdAt)
        XCTAssertNotNil(contributor.modifiedAt)
    }
    
    func testCustomInitialization() {
        let contributor = ContributorEntry(
            project: testProject,
            firstName: "Virginia",
            surname: "Woolf",
            biography: "Modernist author",
            userOrder: 5
        )
        
        XCTAssertEqual(contributor.firstName, "Virginia")
        XCTAssertEqual(contributor.surname, "Woolf")
        XCTAssertEqual(contributor.biography, "Modernist author")
        XCTAssertEqual(contributor.userOrder, 5)
        XCTAssertEqual(contributor.project?.id, testProject.id)
    }
}
