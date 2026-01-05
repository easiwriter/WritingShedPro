import XCTest
import SwiftUI
import SwiftData
@testable import Writing_Shed_Pro

final class AddProjectUITests: XCTestCase {
    
    func testAddProjectSheetCanBeCreated() {
        // This test verifies the AddProjectSheet struct can be instantiated
        let isPresented = true
        let sheet = AddProjectSheet(
            isPresented: .constant(isPresented)
        )
        
        XCTAssertNotNil(sheet)
    }
    
    func testAddProjectSheetInitializesWithEmptyName() {
        let isPresented = true
        let sheet = AddProjectSheet(
            isPresented: .constant(isPresented)
        )
        
        // Verify sheet has empty initial state
        XCTAssertTrue(sheet.projectName.isEmpty)
        XCTAssertEqual(sheet.selectedType, .generalPurpose)
        XCTAssertTrue(sheet.details.isEmpty)
    }
    
    func testAddProjectSheetFictionDefaults() {
        // Verify fiction-specific defaults
        let sheet = AddProjectSheet(
            isPresented: .constant(true)
        )
        
        // Fiction defaults
        XCTAssertEqual(sheet.selectedFictionClass, .novel, "Default fiction class should be novel")
        XCTAssertFalse(sheet.useMonomyth, "Monomyth should be off by default")
    }
    
    func testFictionClassEnum() {
        // Verify FictionClass enum
        XCTAssertEqual(FictionClass.allCases.count, 2)
        XCTAssertEqual(FictionClass.novel.rawValue, "novel")
        XCTAssertEqual(FictionClass.shortFiction.rawValue, "shortFiction")
        
        // Verify localized names exist
        XCTAssertFalse(FictionClass.novel.localizedName.isEmpty)
        XCTAssertFalse(FictionClass.shortFiction.localizedName.isEmpty)
    }
    
    func testContentViewCanBeCreated() {
        let view = ContentView()
        XCTAssertNotNil(view)
    }
    
    func testProjectDetailViewCanBeCreated() {
        let project = Project(name: "Test Project", type: .generalPurpose)
        let view = ProjectDetailView(project: project)
        
        XCTAssertNotNil(view)
    }
}
