//
//  WSPProductTests.swift
//  WritingShedProTests
//
//  Created by Keith Lander on 01/02/2026.
//

import XCTest
@testable import Writing_Shed_Pro

final class WSPProductTests: XCTestCase {
    
    // MARK: - Product ID Tests
    
    func testProductIDsAreCorrect() {
        XCTAssertEqual(WSPProduct.proseWriter.rawValue, "com.writingshedpro.prosewriter")
        XCTAssertEqual(WSPProduct.poetryWriter.rawValue, "com.writingshedpro.poetrywriter")
        XCTAssertEqual(WSPProduct.fictionWriter.rawValue, "com.writingshedpro.fictionwriter")
        XCTAssertEqual(WSPProduct.dramaWriter.rawValue, "com.writingshedpro.dramawriter")
        XCTAssertEqual(WSPProduct.allInBundle.rawValue, "com.writingshedpro.allinbundle")
        XCTAssertEqual(WSPProduct.manuscriptAnalystSubscription.rawValue, "com.writingshedpro.manuscriptanalyst")
    }
    
    func testAllProductIDsContainsAllProducts() {
        let allIDs = WSPProduct.allProductIDs
        XCTAssertEqual(allIDs.count, 6)
        XCTAssertTrue(allIDs.contains(WSPProduct.proseWriter.rawValue))
        XCTAssertTrue(allIDs.contains(WSPProduct.poetryWriter.rawValue))
        XCTAssertTrue(allIDs.contains(WSPProduct.fictionWriter.rawValue))
        XCTAssertTrue(allIDs.contains(WSPProduct.dramaWriter.rawValue))
        XCTAssertTrue(allIDs.contains(WSPProduct.allInBundle.rawValue))
        XCTAssertTrue(allIDs.contains(WSPProduct.manuscriptAnalystSubscription.rawValue))
    }
    
    // MARK: - Project Type Mapping Tests
    
    func testProjectTypeMappingForIndividualModules() {
        XCTAssertEqual(WSPProduct.proseWriter.projectType, .prose)
        XCTAssertEqual(WSPProduct.poetryWriter.projectType, .poetry)
        XCTAssertEqual(WSPProduct.fictionWriter.projectType, .fiction)
        XCTAssertEqual(WSPProduct.dramaWriter.projectType, .drama)
    }
    
    func testBundleHasNoProjectType() {
        XCTAssertNil(WSPProduct.allInBundle.projectType)
        XCTAssertNil(WSPProduct.manuscriptAnalystSubscription.projectType)
    }
    
    func testProductForProjectType() {
        XCTAssertEqual(WSPProduct.product(for: .prose), .proseWriter)
        XCTAssertEqual(WSPProduct.product(for: .poetry), .poetryWriter)
        XCTAssertEqual(WSPProduct.product(for: .fiction), .fictionWriter)
        XCTAssertEqual(WSPProduct.product(for: .drama), .dramaWriter)
    }
    
    // MARK: - Display Properties Tests
    
    func testDisplayNames() {
        XCTAssertEqual(WSPProduct.proseWriter.displayName, "Prose Writer")
        XCTAssertEqual(WSPProduct.poetryWriter.displayName, "Poetry Writer")
        XCTAssertEqual(WSPProduct.fictionWriter.displayName, "Fiction Writer")
        XCTAssertEqual(WSPProduct.dramaWriter.displayName, "Drama Writer")
        XCTAssertEqual(WSPProduct.allInBundle.displayName, "All-in Bundle")
        XCTAssertEqual(WSPProduct.manuscriptAnalystSubscription.displayName, "Manuscript Analyst")
    }
    
    func testShortDescriptions() {
        XCTAssertFalse(WSPProduct.proseWriter.shortDescription.isEmpty)
        XCTAssertFalse(WSPProduct.poetryWriter.shortDescription.isEmpty)
        XCTAssertFalse(WSPProduct.fictionWriter.shortDescription.isEmpty)
        XCTAssertFalse(WSPProduct.dramaWriter.shortDescription.isEmpty)
        XCTAssertFalse(WSPProduct.allInBundle.shortDescription.isEmpty)
        XCTAssertFalse(WSPProduct.manuscriptAnalystSubscription.shortDescription.isEmpty)
    }
    
    func testIconNames() {
        XCTAssertEqual(WSPProduct.proseWriter.iconName, "doc.text")
        XCTAssertEqual(WSPProduct.poetryWriter.iconName, "text.quote")
        XCTAssertEqual(WSPProduct.fictionWriter.iconName, "book")
        XCTAssertEqual(WSPProduct.dramaWriter.iconName, "theatermasks")
        XCTAssertEqual(WSPProduct.allInBundle.iconName, "star.circle.fill")
        XCTAssertEqual(WSPProduct.manuscriptAnalystSubscription.iconName, "sparkles")
    }
    
    // MARK: - Bundle Detection Tests
    
    func testIsBundleProperty() {
        XCTAssertFalse(WSPProduct.proseWriter.isBundle)
        XCTAssertFalse(WSPProduct.poetryWriter.isBundle)
        XCTAssertFalse(WSPProduct.fictionWriter.isBundle)
        XCTAssertFalse(WSPProduct.dramaWriter.isBundle)
        XCTAssertTrue(WSPProduct.allInBundle.isBundle)
        XCTAssertFalse(WSPProduct.manuscriptAnalystSubscription.isBundle)
    }
    
    func testIndividualModulesExcludesBundle() {
        let modules = WSPProduct.individualModules
        XCTAssertEqual(modules.count, 4)
        XCTAssertFalse(modules.contains(.allInBundle))
        XCTAssertTrue(modules.contains(.proseWriter))
        XCTAssertTrue(modules.contains(.poetryWriter))
        XCTAssertTrue(modules.contains(.fictionWriter))
        XCTAssertTrue(modules.contains(.dramaWriter))
    }
    
    // MARK: - Identifiable Conformance Tests
    
    func testIdentifiableConformance() {
        for product in WSPProduct.allCases {
            XCTAssertEqual(product.id, product.rawValue)
        }
    }
    
    // MARK: - CaseIterable Tests
    
    func testAllCasesCount() {
        XCTAssertEqual(WSPProduct.allCases.count, 6)
    }
}
