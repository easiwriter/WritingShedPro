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
    
    func testAllBlockedActionsRequireFullAccess() {
        for type in ProjectType.allCases {
            let reasons: [UpgradePromptReason] = [
                .projectLimit(projectType: type), .fileLimit(projectType: type),
                .exportBlocked(projectType: type), .printBlocked(projectType: type)
            ]
            for reason in reasons {
                XCTAssertEqual(reason.requiredProduct, .fullAccess)
            }
        }
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
    
    func testMessagesContainFullAccessName() {
        let reason = UpgradePromptReason.projectLimit(projectType: .poetry)
        XCTAssertTrue(reason.message.contains(WSPProduct.fullAccess.displayName))
    }
    
    func testMessagesContainProjectType() {
        let reason = UpgradePromptReason.projectLimit(projectType: .fiction)
        XCTAssertTrue(reason.message.contains("fiction"))
    }
}
