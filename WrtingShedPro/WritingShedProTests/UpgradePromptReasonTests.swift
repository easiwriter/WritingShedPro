//
//  UpgradePromptReasonTests.swift
//  WritingShedProTests
//
//  Created by Keith Lander on 01/02/2026.
//

import XCTest
@testable import Writing_Shed_Pro

final class UpgradePromptReasonTests: XCTestCase {
    
    // MARK: - Project Type Tests
    
    func testProjectTypeForProjectLimit() {
        let reason = UpgradePromptReason.projectLimit(projectType: .poetry)
        XCTAssertEqual(reason.projectType, .poetry)
    }
    
    func testProjectTypeForFileLimit() {
        let reason = UpgradePromptReason.fileLimit(projectType: .fiction)
        XCTAssertEqual(reason.projectType, .fiction)
    }
    
    func testProjectTypeForExportBlocked() {
        let reason = UpgradePromptReason.exportBlocked(projectType: .drama)
        XCTAssertEqual(reason.projectType, .drama)
    }
    
    func testProjectTypeForPrintBlocked() {
        let reason = UpgradePromptReason.printBlocked(projectType: .prose)
        XCTAssertEqual(reason.projectType, .prose)
    }
    
    // MARK: - Required Product Tests
    
    func testRequiredProductMapsCorrectly() {
        XCTAssertEqual(
            UpgradePromptReason.projectLimit(projectType: .prose).requiredProduct,
            .proseWriter
        )
        XCTAssertEqual(
            UpgradePromptReason.fileLimit(projectType: .poetry).requiredProduct,
            .poetryWriter
        )
        XCTAssertEqual(
            UpgradePromptReason.exportBlocked(projectType: .fiction).requiredProduct,
            .fictionWriter
        )
        XCTAssertEqual(
            UpgradePromptReason.printBlocked(projectType: .drama).requiredProduct,
            .dramaWriter
        )
    }
    
    // MARK: - Title Tests
    
    func testTitlesAreNotEmpty() {
        let reasons: [UpgradePromptReason] = [
            .projectLimit(projectType: .prose),
            .fileLimit(projectType: .poetry),
            .exportBlocked(projectType: .fiction),
            .printBlocked(projectType: .drama)
        ]
        
        for reason in reasons {
            XCTAssertFalse(reason.title.isEmpty, "Title should not be empty for \(reason)")
        }
    }
    
    func testTitlesAreDistinct() {
        XCTAssertEqual(UpgradePromptReason.projectLimit(projectType: .prose).title, "Project Limit Reached")
        XCTAssertEqual(UpgradePromptReason.fileLimit(projectType: .prose).title, "File Limit Reached")
        XCTAssertEqual(UpgradePromptReason.exportBlocked(projectType: .prose).title, "Export Unavailable")
        XCTAssertEqual(UpgradePromptReason.printBlocked(projectType: .prose).title, "Print Unavailable")
    }
    
    // MARK: - Message Tests
    
    func testMessagesAreNotEmpty() {
        let reasons: [UpgradePromptReason] = [
            .projectLimit(projectType: .prose),
            .fileLimit(projectType: .poetry),
            .exportBlocked(projectType: .fiction),
            .printBlocked(projectType: .drama)
        ]
        
        for reason in reasons {
            XCTAssertFalse(reason.message.isEmpty, "Message should not be empty for \(reason)")
        }
    }
    
    func testMessagesContainModuleName() {
        let reason = UpgradePromptReason.projectLimit(projectType: .poetry)
        XCTAssertTrue(reason.message.contains("Poetry Writer"))
    }
    
    func testMessagesContainProjectType() {
        let reason = UpgradePromptReason.projectLimit(projectType: .fiction)
        XCTAssertTrue(reason.message.contains("fiction"))
    }
}
