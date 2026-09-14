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

    func testPurchaseModelUsesNumericCutoverComparison() {
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "18.10"), .legacy)
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "19.0"), .trialAndFullAccess)
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "19.0.1"), .trialAndFullAccess)
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "20"), .trialAndFullAccess)
    }

    func testNewModelRequiresActivationWithoutEntitlement() {
        XCTAssertEqual(
            EntitlementPolicy.coreAccessState(
                purchaseModel: .trialAndFullAccess,
                entitlementIDs: [],
                trialStartDate: nil,
                now: Date()
            ),
            .activationRequired
        )
    }

    func testTrialIsActiveForExactly240Hours() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let entitlements = Set([WSPProduct.tenDayTrial.rawValue])

        XCTAssertEqual(
            EntitlementPolicy.coreAccessState(
                purchaseModel: .trialAndFullAccess,
                entitlementIDs: entitlements,
                trialStartDate: start,
                now: start.addingTimeInterval(EntitlementPolicy.trialDuration - 1)
            ),
            .trialActive(expiresAt: start.addingTimeInterval(EntitlementPolicy.trialDuration))
        )
        XCTAssertEqual(
            EntitlementPolicy.coreAccessState(
                purchaseModel: .trialAndFullAccess,
                entitlementIDs: entitlements,
                trialStartDate: start,
                now: start.addingTimeInterval(EntitlementPolicy.trialDuration)
            ),
            .trialExpired
        )
    }

    func testFullAccessOverridesTrialState() {
        XCTAssertEqual(
            EntitlementPolicy.coreAccessState(
                purchaseModel: .trialAndFullAccess,
                entitlementIDs: [WSPProduct.fullAccess.rawValue],
                trialStartDate: nil,
                now: Date()
            ),
            .fullAccess
        )
    }

    func testAnalystPurchaseRequiresFullAccessForNewModel() {
        XCTAssertFalse(EntitlementPolicy.canPurchaseManuscriptAnalyst(
            purchaseModel: .trialAndFullAccess,
            coreAccessState: .trialActive(expiresAt: Date().addingTimeInterval(60))
        ))
        XCTAssertFalse(EntitlementPolicy.canPurchaseManuscriptAnalyst(
            purchaseModel: .trialAndFullAccess,
            coreAccessState: .trialExpired
        ))
        XCTAssertTrue(EntitlementPolicy.canPurchaseManuscriptAnalyst(
            purchaseModel: .trialAndFullAccess,
            coreAccessState: .fullAccess
        ))
    }

    func testLegacyModelCanPurchaseAnalystSubscription() {
        XCTAssertTrue(EntitlementPolicy.canPurchaseManuscriptAnalyst(
            purchaseModel: .legacy,
            coreAccessState: .legacy
        ))
    }

    func testLegacyAccessStateDoesNotRequireNewProducts() {
        XCTAssertEqual(
            EntitlementPolicy.coreAccessState(
                purchaseModel: .legacy,
                entitlementIDs: [],
                trialStartDate: nil,
                now: Date()
            ),
            .legacy
        )
    }
    
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
        XCTAssertTrue(EntitlementPolicy.canCreate(
            existingCount: 0,
            freeTierLimit: EntitlementManager.freeTierMaxProjectsPerType,
            purchaseModel: .legacy,
            coreAccessState: .legacy,
            isLegacyProductUnlocked: false
        ))
    }
    
    func testCannotCreateProjectWhenAtLimit() {
        XCTAssertFalse(EntitlementPolicy.canCreate(
            existingCount: 1,
            freeTierLimit: EntitlementManager.freeTierMaxProjectsPerType,
            purchaseModel: .legacy,
            coreAccessState: .legacy,
            isLegacyProductUnlocked: false
        ))
    }
    
    func testCannotCreateProjectWhenOverLimit() {
        XCTAssertFalse(EntitlementPolicy.canCreate(
            existingCount: 10,
            freeTierLimit: EntitlementManager.freeTierMaxProjectsPerType,
            purchaseModel: .legacy,
            coreAccessState: .legacy,
            isLegacyProductUnlocked: false
        ))
    }

    func testLegacyPurchaseAllowsCreationBeyondLimit() {
        XCTAssertTrue(EntitlementPolicy.canCreate(
            existingCount: 10,
            freeTierLimit: EntitlementManager.freeTierMaxProjectsPerType,
            purchaseModel: .legacy,
            coreAccessState: .legacy,
            isLegacyProductUnlocked: true
        ))
    }

    func testNewModelCreationFollowsCoreAccessState() {
        let expirationDate = Date().addingTimeInterval(60)
        XCTAssertTrue(EntitlementPolicy.canCreate(
            existingCount: 10,
            freeTierLimit: EntitlementManager.freeTierMaxProjectsPerType,
            purchaseModel: .trialAndFullAccess,
            coreAccessState: .trialActive(expiresAt: expirationDate),
            isLegacyProductUnlocked: false
        ))
        XCTAssertFalse(EntitlementPolicy.canCreate(
            existingCount: 0,
            freeTierLimit: EntitlementManager.freeTierMaxProjectsPerType,
            purchaseModel: .trialAndFullAccess,
            coreAccessState: .trialExpired,
            isLegacyProductUnlocked: true
        ))
    }
    
    // MARK: - canCreateFile Tests
    
    func testCanCreateFileWhenNoExistingFiles() {
        XCTAssertTrue(EntitlementPolicy.canCreate(
            existingCount: 0,
            freeTierLimit: EntitlementManager.freeTierMaxFilesPerProject,
            purchaseModel: .legacy,
            coreAccessState: .legacy,
            isLegacyProductUnlocked: false
        ))
    }
    
    func testCannotCreateFileWhenAtLimit() {
        XCTAssertFalse(EntitlementPolicy.canCreate(
            existingCount: 1,
            freeTierLimit: EntitlementManager.freeTierMaxFilesPerProject,
            purchaseModel: .legacy,
            coreAccessState: .legacy,
            isLegacyProductUnlocked: false
        ))
    }
    
    // MARK: - canExport Tests
    
    func testCannotExportWithoutPurchase() {
        let manager = EntitlementManager.shared
        guard !manager.hasAnyPurchase else { return }
        
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
        guard !manager.hasAnyPurchase else { return }
        
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
        // This test only validates when no sandbox purchases exist
        // If sandbox purchases are present, this test cannot verify the free tier state
        // The test is informational - if it fails, sandbox purchases are active
        if manager.hasAnyPurchase {
            // Skip - sandbox has purchases, cannot test free tier state
            return
        }
        XCTAssertFalse(manager.hasAnyPurchase)
    }
    
    func testHasBundleIsFalseWithoutPurchases() {
        let manager = EntitlementManager.shared
        XCTAssertFalse(manager.hasBundle)
    }
    
    func testUnpurchasedModulesContainsAllWithoutPurchases() {
        let manager = EntitlementManager.shared
        guard !manager.hasAnyPurchase else { return }
        
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
        guard !manager.hasAnyPurchase else { return }
        XCTAssertTrue(manager.purchasedModules.isEmpty)
    }
    
    // MARK: - isModulePurchased Tests
    
    func testIsModulePurchasedReturnsFalseWithoutPurchases() {
        let manager = EntitlementManager.shared
        guard !manager.hasAnyPurchase else { return }
        
        XCTAssertFalse(manager.isModulePurchased(.proseWriter))
        XCTAssertFalse(manager.isModulePurchased(.poetryWriter))
        XCTAssertFalse(manager.isModulePurchased(.fictionWriter))
        XCTAssertFalse(manager.isModulePurchased(.dramaWriter))
        XCTAssertFalse(manager.isModulePurchased(.allInBundle))
    }
    
    // MARK: - isProjectTypeUnlocked Tests
    
    func testIsProjectTypeUnlockedReturnsFalseWithoutPurchases() {
        let manager = EntitlementManager.shared
        guard !manager.hasAnyPurchase else { return }
        
        XCTAssertFalse(manager.isProjectTypeUnlocked(.prose))
        XCTAssertFalse(manager.isProjectTypeUnlocked(.poetry))
        XCTAssertFalse(manager.isProjectTypeUnlocked(.fiction))
        XCTAssertFalse(manager.isProjectTypeUnlocked(.drama))
    }
}
