import XCTest
import SwiftUI
import SwiftData
@testable import Writing_Shed_Pro

final class AddProjectUITests: XCTestCase {
    
    func testAddProjectSheetCanBeCreated() {
        // This test verifies the AddProjectSheet struct can be instantiated
        let isPresented = true
        let sheet = AddProjectSheet(
            isPresented: .constant(isPresented),
            projects: []
        )
        
        XCTAssertNotNil(sheet)
    }
    
    func testAddProjectSheetInitializesWithEmptyName() {
        let isPresented = true
        let sheet = AddProjectSheet(
            isPresented: .constant(isPresented),
            projects: []
        )
        
        // Verify sheet has empty initial state
        XCTAssertTrue(sheet.projectName.isEmpty)
        XCTAssertEqual(sheet.selectedType, .blank)
        XCTAssertTrue(sheet.details.isEmpty)
    }
    
    func testContentViewCanBeCreated() {
        let view = ContentView()
        XCTAssertNotNil(view)
    }
    
    func testProjectDetailViewCanBeCreated() {
        let project = Project(name: "Test Project", type: .blank)
        let view = ProjectDetailView(project: project)
        
        XCTAssertNotNil(view)
    }
}
