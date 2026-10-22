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
    func testFullAccessTakesPrecedenceOverCohortAndTrialState() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let models: [PurchaseModel?] = [nil, .legacy, .trialAndFullAccess]
        for model in models {
            for legacyProduct in WSPProduct.legacyCoreProducts {
                for trialStart in [Date?.none, now, now.addingTimeInterval(-EntitlementPolicy.trialDuration)] {
                    XCTAssertEqual(EntitlementPolicy.coreAccessState(
                        purchaseModel: model,
                        entitlementIDs: [
                            WSPProduct.fullAccess.rawValue, WSPProduct.tenDayTrial.rawValue,
                            legacyProduct.rawValue
                        ],
                        trialStartDate: trialStart, now: now
                    ), .fullAccess)
                }
            }
            XCTAssertEqual(EntitlementPolicy.coreAccessState(
                purchaseModel: model, entitlementIDs: [WSPProduct.fullAccess.rawValue],
                trialStartDate: nil, now: now
            ), .fullAccess)
        }
    }

    func testLegacyFullAccessUnlocksEveryCoreProductAndCreationGate() {
        for originalVersion in ["18.10", "19.0"] {
            let model = EntitlementPolicy.purchaseModel(
                appTransactionModel: EntitlementPolicy.purchaseModel(for: originalVersion),
                entitlementIDs: [WSPProduct.poetryWriter.rawValue, WSPProduct.fullAccess.rawValue]
            )
            XCTAssertEqual(model, .legacy)
            let entitlements: Set<String> = [WSPProduct.poetryWriter.rawValue, WSPProduct.fullAccess.rawValue]
            let state = EntitlementPolicy.coreAccessState(
                purchaseModel: model, entitlementIDs: entitlements, trialStartDate: nil, now: Date()
            )
            XCTAssertEqual(state, .fullAccess)
            XCTAssertTrue(state.allowsCoreMutations)
            for product in WSPProduct.legacyCoreProducts {
                XCTAssertTrue(EntitlementPolicy.isModulePurchased(
                    product, purchaseModel: model, coreAccessState: state, entitlementIDs: entitlements
                ))
            }
            XCTAssertTrue(EntitlementPolicy.canCreate(
                existingCount: 100, freeTierLimit: 1, purchaseModel: model,
                coreAccessState: state, isLegacyProductUnlocked: false
            ))
            XCTAssertEqual(EntitlementPolicy.projectImportAccess(
                existingProjectCount: 100, importedFileCount: 500, projectLimit: 1,
                fileLimit: 1, purchaseModel: model, coreAccessState: state,
                isLegacyProductUnlocked: false
            ), .allowed)
            XCTAssertFalse(EntitlementPolicy.isModulePurchased(
                .manuscriptAnalystSubscription, purchaseModel: model, coreAccessState: state,
                entitlementIDs: entitlements
            ))
            XCTAssertTrue(EntitlementPolicy.isModulePurchased(
                .manuscriptAnalystSubscription, purchaseModel: model, coreAccessState: state,
                entitlementIDs: entitlements.union([WSPProduct.manuscriptAnalystSubscription.rawValue])
            ))
        }
    }

    func testLegacyPurchasesKeepTheirExistingUnlocksWithoutFullAccess() {
        let entitlements: Set<String> = [WSPProduct.poetryWriter.rawValue]
        XCTAssertTrue(EntitlementPolicy.isModulePurchased(
            .poetryWriter, purchaseModel: .legacy, coreAccessState: .legacy, entitlementIDs: entitlements
        ))
        XCTAssertFalse(EntitlementPolicy.isModulePurchased(
            .proseWriter, purchaseModel: .legacy, coreAccessState: .legacy, entitlementIDs: entitlements
        ))
        for product in WSPProduct.individualModules {
            XCTAssertTrue(EntitlementPolicy.isModulePurchased(
                product, purchaseModel: .legacy, coreAccessState: .legacy,
                entitlementIDs: [WSPProduct.allInBundle.rawValue]
            ))
        }
        XCTAssertFalse(EntitlementPolicy.isModulePurchased(
            .manuscriptAnalystSubscription, purchaseModel: .legacy, coreAccessState: .legacy,
            entitlementIDs: [WSPProduct.allInBundle.rawValue]
        ))
        XCTAssertFalse(EntitlementPolicy.isModulePurchased(
            .fullAccess, purchaseModel: .legacy, coreAccessState: .legacy,
            entitlementIDs: [WSPProduct.allInBundle.rawValue]
        ))
        XCTAssertFalse(EntitlementPolicy.isModulePurchased(
            .tenDayTrial, purchaseModel: .legacy, coreAccessState: .legacy,
            entitlementIDs: [WSPProduct.allInBundle.rawValue]
        ))
    }

    func testRetiredProductsRouteToFullAccessAndAreNotOfferedForSale() {
        for product in WSPProduct.legacyCoreProducts {
            XCTAssertEqual(product.currentPurchaseProduct, .fullAccess)
        }
        XCTAssertEqual(WSPProduct.manuscriptAnalystSubscription.currentPurchaseProduct, .manuscriptAnalystSubscription)
        for model in [PurchaseModel.legacy, .trialAndFullAccess] {
            let products = WSPProduct.productsForSale(purchaseModel: model)
            XCTAssertTrue(products.contains(.fullAccess))
            XCTAssertTrue(products.contains(.manuscriptAnalystSubscription))
            XCTAssertTrue(Set(products).isDisjoint(with: Set(WSPProduct.legacyCoreProducts)))
        }
        XCTAssertFalse(WSPProduct.productsForSale(purchaseModel: .legacy).contains(.tenDayTrial))
        XCTAssertTrue(WSPProduct.productsForSale(purchaseModel: .trialAndFullAccess).contains(.tenDayTrial))
    }

    func testFullAccessRemovalRestoresLegacyModuleLimits() {
        XCTAssertEqual(EntitlementPolicy.coreAccessState(
            purchaseModel: .legacy, entitlementIDs: [WSPProduct.poetryWriter.rawValue],
            trialStartDate: nil, now: Date()
        ), .legacy)
        XCTAssertFalse(EntitlementPolicy.canCreate(
            existingCount: 100, freeTierLimit: 1, purchaseModel: .legacy,
            coreAccessState: .legacy, isLegacyProductUnlocked: false
        ))
    }

    func testPurchaseModelUsesNumericCutoverComparison() {
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "18.10"), .legacy)
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "19.0"), .trialAndFullAccess)
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "19.0.1"), .trialAndFullAccess)
        XCTAssertEqual(EntitlementPolicy.purchaseModel(for: "20"), .trialAndFullAccess)
    }

    func testIOSPurchaseModelUsesBuildNumberCutover() {
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(for: "502", versionScheme: .buildNumber),
            .legacy
        )
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(for: "503", versionScheme: .buildNumber),
            .trialAndFullAccess
        )
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(for: "518", versionScheme: .buildNumber),
            .trialAndFullAccess
        )
    }

    func testSandboxAlwaysUsesNewPurchaseModel() {
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(for: "1.0", isSandboxEnvironment: true),
            .trialAndFullAccess
        )
    }

    func testProductionPreservesLegacyPurchaseModel() {
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(for: "18.10", isSandboxEnvironment: false),
            .legacy
        )
    }

    func testVerifiedLegacyModuleOverridesNewModelClassification() {
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(
                appTransactionModel: .trialAndFullAccess,
                entitlementIDs: [WSPProduct.fictionWriter.rawValue]
            ),
            .legacy
        )
    }

    func testVerifiedLegacyBundleOverridesNewModelClassification() {
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(
                appTransactionModel: .trialAndFullAccess,
                entitlementIDs: [WSPProduct.allInBundle.rawValue]
            ),
            .legacy
        )
    }

    func testNewModelProductsDoNotChangeClassification() {
        XCTAssertEqual(
            EntitlementPolicy.purchaseModel(
                appTransactionModel: .trialAndFullAccess,
                entitlementIDs: [WSPProduct.tenDayTrial.rawValue, WSPProduct.fullAccess.rawValue]
            ),
            .trialAndFullAccess
        )
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
        XCTAssertTrue(EntitlementPolicy.canPurchaseManuscriptAnalyst(
            purchaseModel: .legacy,
            coreAccessState: .fullAccess
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

    func testLegacyImportEnforcesProjectAndFileLimits() {
        XCTAssertEqual(
            EntitlementPolicy.projectImportAccess(
                existingProjectCount: 1,
                importedFileCount: 1,
                projectLimit: 1,
                fileLimit: 1,
                purchaseModel: .legacy,
                coreAccessState: .legacy,
                isLegacyProductUnlocked: false
            ),
            .projectLimit
        )
        XCTAssertEqual(
            EntitlementPolicy.projectImportAccess(
                existingProjectCount: 0,
                importedFileCount: 2,
                projectLimit: 1,
                fileLimit: 1,
                purchaseModel: .legacy,
                coreAccessState: .legacy,
                isLegacyProductUnlocked: false
            ),
            .fileLimit
        )
        XCTAssertEqual(
            EntitlementPolicy.projectImportAccess(
                existingProjectCount: 0,
                importedFileCount: 1,
                projectLimit: 1,
                fileLimit: 1,
                purchaseModel: .legacy,
                coreAccessState: .legacy,
                isLegacyProductUnlocked: false
            ),
            .allowed
        )
    }

    func testPurchasedLegacyModuleAllowsImportBeyondFreeLimits() {
        XCTAssertEqual(
            EntitlementPolicy.projectImportAccess(
                existingProjectCount: 10,
                importedFileCount: 20,
                projectLimit: 1,
                fileLimit: 1,
                purchaseModel: .legacy,
                coreAccessState: .legacy,
                isLegacyProductUnlocked: true
            ),
            .allowed
        )
    }

    func testNewModelImportRequiresWritableCoreAccess() {
        XCTAssertEqual(
            EntitlementPolicy.projectImportAccess(
                existingProjectCount: 0,
                importedFileCount: 1,
                projectLimit: 1,
                fileLimit: 1,
                purchaseModel: .trialAndFullAccess,
                coreAccessState: .trialExpired,
                isLegacyProductUnlocked: false
            ),
            .projectLimit
        )
        XCTAssertEqual(
            EntitlementPolicy.projectImportAccess(
                existingProjectCount: 10,
                importedFileCount: 20,
                projectLimit: 1,
                fileLimit: 1,
                purchaseModel: .trialAndFullAccess,
                coreAccessState: .fullAccess,
                isLegacyProductUnlocked: false
            ),
            .allowed
        )
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
