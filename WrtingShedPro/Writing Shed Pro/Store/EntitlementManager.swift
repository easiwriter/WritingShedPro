//
//  EntitlementManager.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import Foundation
import SwiftData
import StoreKitManager
import Observation

// MARK: - Entitlement Manager

/// Manages purchase entitlements and free tier gating for Writing Shed Pro.
/// Uses StoreKitManager package for all StoreKit 2 interactions.
@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
@Observable
@MainActor
final class EntitlementManager {
    
    // MARK: - Singleton
    
    static let shared = EntitlementManager()
    
    // MARK: - Properties
    
    /// Reference to the StoreKit purchase manager
    private var purchaseManager: StoreKitPurchaseManager {
        StoreKitPurchaseManager.shared
    }
    
    /// Cached entitlement state for quick access
    private(set) var cachedEntitlements: Set<String> = []
    
    /// Whether entitlements have been loaded
    private(set) var isLoaded: Bool = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Setup
    
    /// Configure the manager and load initial entitlements
    func configure() async {
        await refreshEntitlements()
    }
    
    /// Refresh entitlements from StoreKit
    func refreshEntitlements() async {
        await purchaseManager.checkEntitlement()
        cachedEntitlements = purchaseManager.entitledProductIDs
        isLoaded = true
        
        #if DEBUG
        print("📦 [EntitlementManager] Loaded entitlements: \(cachedEntitlements)")
        #endif
    }
    
    // MARK: - Purchase Status Checks
    
    /// Check if a specific product is purchased
    func isModulePurchased(_ product: WSPProduct) -> Bool {
        // Bundle unlocks everything
        if purchaseManager.isEntitled(to: WSPProduct.allInBundle.rawValue) {
            return true
        }
        return purchaseManager.isEntitled(to: product.rawValue)
    }
    
    /// Check if a project type is unlocked (purchased or bundle)
    func isProjectTypeUnlocked(_ type: ProjectType) -> Bool {
        let product = WSPProduct.product(for: type)
        return isModulePurchased(product)
    }
    
    /// Check if user has any purchases
    var hasAnyPurchase: Bool {
        !purchaseManager.entitledProductIDs.isEmpty
    }
    
    /// Check if user has purchased the full bundle
    var hasBundle: Bool {
        purchaseManager.isEntitled(to: WSPProduct.allInBundle.rawValue)
    }
    
    /// Check if user has purchased at least one individual module (not via bundle)
    var hasAnyIndividualModulePurchase: Bool {
        guard !hasBundle else { return false }  // Bundle doesn't count as individual
        return WSPProduct.individualModules.contains { product in
            purchaseManager.isEntitled(to: product.rawValue)
        }
    }
    
    /// Get list of all purchased modules (excluding bundle)
    var purchasedModules: [WSPProduct] {
        WSPProduct.individualModules.filter { isModulePurchased($0) }
    }
    
    /// Get list of modules not yet purchased
    var unpurchasedModules: [WSPProduct] {
        if hasBundle { return [] }
        return WSPProduct.individualModules.filter { !isModulePurchased($0) }
    }
    
    // MARK: - Free Tier Limit Checks
    
    /// Check if user can create a new project of the given type
    /// - Parameters:
    ///   - type: The project type to create
    ///   - existingCount: Number of existing projects of this type
    /// - Returns: true if allowed, false if limit reached
    func canCreateProject(ofType type: ProjectType, existingCount: Int) -> Bool {
        if isProjectTypeUnlocked(type) {
            return true  // No limit if purchased
        }
        return existingCount < 1  // Free tier: max 1 project per type
    }
    
    /// Check if user can create a new file in the given project
    /// - Parameters:
    ///   - projectType: The type of the parent project
    ///   - existingCount: Number of existing files in the project
    /// - Returns: true if allowed, false if limit reached
    func canCreateFile(forProjectType projectType: ProjectType, existingCount: Int) -> Bool {
        if isProjectTypeUnlocked(projectType) {
            return true  // No limit if purchased
        }
        return existingCount < 1  // Free tier: max 1 file per project
    }
    
    /// Check if user can export from a project of the given type
    func canExport(projectType: ProjectType) -> Bool {
        return isProjectTypeUnlocked(projectType)
    }
    
    /// Check if user can print from a project of the given type
    func canPrint(projectType: ProjectType) -> Bool {
        return isProjectTypeUnlocked(projectType)
    }
    
    // MARK: - Free Tier Limits
    
    /// Maximum projects per type for free tier
    static let freeTierMaxProjectsPerType = 1
    
    /// Maximum files per project for free tier
    static let freeTierMaxFilesPerProject = 1
}

// MARK: - Upgrade Prompt Context

/// Context for showing upgrade prompts - describes what action was blocked
enum UpgradePromptReason {
    case projectLimit(projectType: ProjectType)
    case fileLimit(projectType: ProjectType)
    case exportBlocked(projectType: ProjectType)
    case printBlocked(projectType: ProjectType)
    
    /// The project type associated with this prompt
    var projectType: ProjectType {
        switch self {
        case .projectLimit(let type): return type
        case .fileLimit(let type): return type
        case .exportBlocked(let type): return type
        case .printBlocked(let type): return type
        }
    }
    
    /// The product needed to unlock this feature
    var requiredProduct: WSPProduct {
        WSPProduct.product(for: projectType)
    }
    
    /// User-facing title for the prompt
    var title: String {
        switch self {
        case .projectLimit:
            return "Project Limit Reached"
        case .fileLimit:
            return "File Limit Reached"
        case .exportBlocked:
            return "Export Unavailable"
        case .printBlocked:
            return "Print Unavailable"
        }
    }
    
    /// User-facing message for the prompt
    var message: String {
        let moduleName = requiredProduct.displayName
        switch self {
        case .projectLimit(let type):
            return "Free accounts can create 1 \(type.rawValue) project. Upgrade to \(moduleName) for unlimited projects."
        case .fileLimit(let type):
            return "Free accounts can create 1 file per \(type.rawValue) project. Upgrade to \(moduleName) for unlimited files."
        case .exportBlocked:
            return "Exporting requires \(moduleName). Upgrade to export your work."
        case .printBlocked:
            return "Printing requires \(moduleName). Upgrade to print your work."
        }
    }
}
