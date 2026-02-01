//
//  EntitlementManagerTests.swift
//  WritingShedProTests
//
//  Created by Keith Lander on 01/02/2026.
//

import XCTest
@testable import Writing_Shed_Pro

/// Unit tests for EntitlementManager free tier gating logic.
/// Note: These tests run against the live EntitlementManager singleton.
/// Without StoreKit sandbox purchases, all entitlement checks return false (free tier).
@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
@MainActor
final class EntitlementManagerTests: XCTestCase {
    
    // MARK: - Free Tier Limit Constants
    
    func testFreeTierMaxProjectsPerType() {
        XCTAssertEqual(EntitlementManager.freeTierMaxProjectsPerType, 1)
    }
    
    func testFreeTierMaxFilesPerProject() {
        XCTAssertEqual(EntitlementManager.freeTierMaxFilesPerProject, 1)
    }
    
    // MARK: - canCreateProject Tests
    
    /// Note: These tests verify the logic in isolation.
    /// In actual use, EntitlementManager checks StoreKit for purchases.
    /// For free tier (no purchases), these are the expected behaviors.
    
    func testCanCreateProjectWhenNoExistingProjects() {
        // Free tier allows 1 project per type
        // When existingCount = 0, should allow creation
        let manager = EntitlementManager.shared
        
        // We can't easily mock the purchase state, but we can verify
        // the limit logic by testing with existingCount
        XCTAssertTrue(manager.canCreateProject(ofType: .prose, existingCount: 0))
        XCTAssertTrue(manager.canCreateProject(ofType: .poetry, existingCount: 0))
        XCTAssertTrue(manager.canCreateProject(ofType: .fiction, existingCount: 0))
        XCTAssertTrue(manager.canCreateProject(ofType: .drama, existingCount: 0))
    }
    
    func testCannotCreateProjectWhenAtLimit() {
        // Free tier allows 1 project per type
        // When existingCount = 1, should block creation (unless purchased)
        let manager = EntitlementManager.shared
        
        // Note: This assumes no purchases - in real use, if user has purchased
        // the module, this would return true regardless of count
        // The logic is: if purchased, unlimited; if not, limit to 1
        
        // Without mocking, we're testing the unpurchased path
        // These tests verify the count checking logic works
        XCTAssertFalse(manager.canCreateProject(ofType: .prose, existingCount: 1))
        XCTAssertFalse(manager.canCreateProject(ofType: .poetry, existingCount: 1))
        XCTAssertFalse(manager.canCreateProject(ofType: .fiction, existingCount: 1))
        XCTAssertFalse(manager.canCreateProject(ofType: .drama, existingCount: 1))
    }
    
    func testCannotCreateProjectWhenOverLimit() {
        let manager = EntitlementManager.shared
        
        // Even with 5 existing projects, should block
        XCTAssertFalse(manager.canCreateProject(ofType: .prose, existingCount: 5))
        XCTAssertFalse(manager.canCreateProject(ofType: .poetry, existingCount: 10))
    }
    
    // MARK: - canCreateFile Tests
    
    func testCanCreateFileWhenNoExistingFiles() {
        let manager = EntitlementManager.shared
        
        // Free tier allows 1 file per project
        XCTAssertTrue(manager.canCreateFile(forProjectType: .prose, existingCount: 0))
        XCTAssertTrue(manager.canCreateFile(forProjectType: .poetry, existingCount: 0))
        XCTAssertTrue(manager.canCreateFile(forProjectType: .fiction, existingCount: 0))
        XCTAssertTrue(manager.canCreateFile(forProjectType: .drama, existingCount: 0))
    }
    
    func testCannotCreateFileWhenAtLimit() {
        let manager = EntitlementManager.shared
        
        // Free tier allows 1 file per project
        XCTAssertFalse(manager.canCreateFile(forProjectType: .prose, existingCount: 1))
        XCTAssertFalse(manager.canCreateFile(forProjectType: .poetry, existingCount: 1))
        XCTAssertFalse(manager.canCreateFile(forProjectType: .fiction, existingCount: 1))
        XCTAssertFalse(manager.canCreateFile(forProjectType: .drama, existingCount: 1))
    }
    
    // MARK: - canExport Tests
    
    func testCannotExportWithoutPurchase() {
        let manager = EntitlementManager.shared
        
        // Export is blocked for free tier
        // Note: If user has purchased module, this returns true
        XCTAssertFalse(manager.canExport(projectType: .prose))
        XCTAssertFalse(manager.canExport(projectType: .poetry))
        XCTAssertFalse(manager.canExport(projectType: .fiction))
        XCTAssertFalse(manager.canExport(projectType: .drama))
    }
    
    // MARK: - canPrint Tests
    
    func testCannotPrintWithoutPurchase() {
        let manager = EntitlementManager.shared
        
        // Print is blocked for free tier
        XCTAssertFalse(manager.canPrint(projectType: .prose))
        XCTAssertFalse(manager.canPrint(projectType: .poetry))
        XCTAssertFalse(manager.canPrint(projectType: .fiction))
        XCTAssertFalse(manager.canPrint(projectType: .drama))
    }
    
    // MARK: - Singleton Tests
    
    func testSharedInstanceExists() {
        XCTAssertNotNil(EntitlementManager.shared)
    }
    
    func testSharedInstanceIsSameInstance() {
        let instance1 = EntitlementManager.shared
        let instance2 = EntitlementManager.shared
        XCTAssertTrue(instance1 === instance2)
    }
    
    // MARK: - Initial State Tests
    
    func testIsLoadedPropertyExists() {
        // Verify the property is accessible
        let manager = EntitlementManager.shared
        // Just check the property exists (it may be true or false depending on test order)
        _ = manager.isLoaded
    }
    
    func testCachedEntitlementsPropertyExists() {
        let manager = EntitlementManager.shared
        // Verify the property is accessible
        _ = manager.cachedEntitlements
    }
    
    // MARK: - Purchase Status Tests (Without Purchases)
    
    func testHasAnyPurchaseIsFalseWithoutPurchases() {
        let manager = EntitlementManager.shared
        // Assuming no StoreKit sandbox purchases
        XCTAssertFalse(manager.hasAnyPurchase)
    }
    
    func testHasBundleIsFalseWithoutPurchases() {
        let manager = EntitlementManager.shared
        XCTAssertFalse(manager.hasBundle)
    }
    
    func testUnpurchasedModulesContainsAllWithoutPurchases() {
        let manager = EntitlementManager.shared
        
        // Without purchases, all modules should be in unpurchasedModules
        let unpurchased = manager.unpurchasedModules
        XCTAssertEqual(unpurchased.count, 4)
        XCTAssertTrue(unpurchased.contains(.proseWriter))
        XCTAssertTrue(unpurchased.contains(.poetryWriter))
        XCTAssertTrue(unpurchased.contains(.fictionWriter))
        XCTAssertTrue(unpurchased.contains(.dramaWriter))
    }
    
    func testPurchasedModulesIsEmptyWithoutPurchases() {
        let manager = EntitlementManager.shared
        XCTAssertTrue(manager.purchasedModules.isEmpty)
    }
    
    // MARK: - isModulePurchased Tests
    
    func testIsModulePurchasedReturnsFalseWithoutPurchases() {
        let manager = EntitlementManager.shared
        
        XCTAssertFalse(manager.isModulePurchased(.proseWriter))
        XCTAssertFalse(manager.isModulePurchased(.poetryWriter))
        XCTAssertFalse(manager.isModulePurchased(.fictionWriter))
        XCTAssertFalse(manager.isModulePurchased(.dramaWriter))
        XCTAssertFalse(manager.isModulePurchased(.allInBundle))
    }
    
    // MARK: - isProjectTypeUnlocked Tests
    
    func testIsProjectTypeUnlockedReturnsFalseWithoutPurchases() {
        let manager = EntitlementManager.shared
        
        XCTAssertFalse(manager.isProjectTypeUnlocked(.prose))
        XCTAssertFalse(manager.isProjectTypeUnlocked(.poetry))
        XCTAssertFalse(manager.isProjectTypeUnlocked(.fiction))
        XCTAssertFalse(manager.isProjectTypeUnlocked(.drama))
    }
}
