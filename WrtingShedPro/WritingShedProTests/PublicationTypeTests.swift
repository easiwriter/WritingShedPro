//
//  PublicationTypeTests.swift
//  WritingShedProTests
//
//  Tests for PublicationType enum and project-specific type filtering
//

import XCTest
@testable import Writing_Shed_Pro

final class PublicationTypeTests: XCTestCase {
    
    // MARK: - All Cases
    
    func testAllCasesCount() {
        // Should have 6 publication types: magazine, competition, commission, publisher, agent, other
        XCTAssertEqual(PublicationType.allCases.count, 6)
    }
    
    func testAllCasesContainsExpectedTypes() {
        let allCases = PublicationType.allCases
        
        XCTAssertTrue(allCases.contains(.magazine))
        XCTAssertTrue(allCases.contains(.competition))
        XCTAssertTrue(allCases.contains(.commission))
        XCTAssertTrue(allCases.contains(.publisher))
        XCTAssertTrue(allCases.contains(.agent))
        XCTAssertTrue(allCases.contains(.other))
    }
    
    // MARK: - Display Names
    
    func testDisplayNames() {
        // Each type should have a non-empty display name
        for type in PublicationType.allCases {
            XCTAssertFalse(type.displayName.isEmpty, "\(type) should have a display name")
        }
    }
    
    // MARK: - Icons
    
    func testIcons() {
        // Each type should have a non-empty icon
        for type in PublicationType.allCases {
            XCTAssertFalse(type.icon.isEmpty, "\(type) should have an icon")
        }
        
        // Verify specific icons
        XCTAssertEqual(PublicationType.magazine.icon, "📰")
        XCTAssertEqual(PublicationType.competition.icon, "🏆")
        XCTAssertEqual(PublicationType.commission.icon, "📝")
        XCTAssertEqual(PublicationType.publisher.icon, "📚")
        XCTAssertEqual(PublicationType.agent.icon, "🤝")
        XCTAssertEqual(PublicationType.other.icon, "📄")
    }
    
    // MARK: - Available Types for Project Types
    
    func testAvailableTypesForPoetry() {
        let types = PublicationType.availableTypes(for: .poetry)
        
        // Poetry should have: magazine, competition, other
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(.magazine))
        XCTAssertTrue(types.contains(.competition))
        XCTAssertTrue(types.contains(.other))
        
        // Should NOT have publisher/agent (those are for long-form works)
        XCTAssertFalse(types.contains(.publisher))
        XCTAssertFalse(types.contains(.agent))
        XCTAssertFalse(types.contains(.commission))
    }
    
    func testAvailableTypesForProse() {
        let types = PublicationType.availableTypes(for: .prose)
        
        // Prose should have: publisher, agent, other
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(.publisher))
        XCTAssertTrue(types.contains(.agent))
        XCTAssertTrue(types.contains(.other))
        
        // Should NOT have magazine/competition (those are for poetry)
        XCTAssertFalse(types.contains(.magazine))
        XCTAssertFalse(types.contains(.competition))
    }
    
    func testAvailableTypesForFiction() {
        let types = PublicationType.availableTypes(for: .fiction)
        
        // Fiction should have: publisher, agent, other
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(.publisher))
        XCTAssertTrue(types.contains(.agent))
        XCTAssertTrue(types.contains(.other))
    }
    
    func testAvailableTypesForDrama() {
        let types = PublicationType.availableTypes(for: .drama)
        
        // Drama should have: publisher, agent, other
        XCTAssertEqual(types.count, 3)
        XCTAssertTrue(types.contains(.publisher))
        XCTAssertTrue(types.contains(.agent))
        XCTAssertTrue(types.contains(.other))
    }
    
    // MARK: - Raw Values (for Codable)
    
    func testRawValues() {
        XCTAssertEqual(PublicationType.magazine.rawValue, "magazine")
        XCTAssertEqual(PublicationType.competition.rawValue, "competition")
        XCTAssertEqual(PublicationType.commission.rawValue, "commission")
        XCTAssertEqual(PublicationType.publisher.rawValue, "publisher")
        XCTAssertEqual(PublicationType.agent.rawValue, "agent")
        XCTAssertEqual(PublicationType.other.rawValue, "other")
    }
    
    func testInitFromRawValue() {
        XCTAssertEqual(PublicationType(rawValue: "magazine"), .magazine)
        XCTAssertEqual(PublicationType(rawValue: "competition"), .competition)
        XCTAssertEqual(PublicationType(rawValue: "commission"), .commission)
        XCTAssertEqual(PublicationType(rawValue: "publisher"), .publisher)
        XCTAssertEqual(PublicationType(rawValue: "agent"), .agent)
        XCTAssertEqual(PublicationType(rawValue: "other"), .other)
        XCTAssertNil(PublicationType(rawValue: "invalid"))
    }
}
