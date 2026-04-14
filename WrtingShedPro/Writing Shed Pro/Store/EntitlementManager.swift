//
//  EntitlementManager.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import Foundation
import Network
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

    /// Product IDs verified directly from purchase transactions within this session.
    /// Merged into cachedEntitlements so we don't lose a purchase just because
    /// Transaction.currentEntitlements is slow to update (known iOS StoreKit issue).
    private var locallyVerifiedProductIDs: Set<String> = []

    /// True when: entitlements loaded, no purchases found, AND the device was offline
    /// during the initial load. Clears automatically when purchases are verified online.
    private(set) var showOfflinePurchaseWarning: Bool = false

    /// Network path monitor — watches for connectivity changes so we can re-verify
    /// entitlements as soon as connectivity is restored.
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.writingshedpro.entitlement.network")
    private var hasConfirmedNetworkPath = false
    private var isNetworkReachable = true

#if DEBUG
    private static let paywallCaptureModeKey = "debug.paywallCaptureMode"
#endif
    
    // MARK: - Initialization
    
    private init() {}

#if DEBUG
    var isPaywallCaptureModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.paywallCaptureModeKey)
    }

    func setPaywallCaptureModeEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: Self.paywallCaptureModeKey)
        await refreshEntitlements()
    }

    func resetPaywallCaptureState() async {
        UserDefaults.standard.removeObject(forKey: Self.paywallCaptureModeKey)
        await refreshEntitlements()
    }
#endif
    
    // MARK: - Setup
    
    /// Configure the manager and load initial entitlements
    func configure() async {
        startNetworkMonitoring()
        await refreshEntitlements()
    }
    
    /// Refresh entitlements from StoreKit
    func refreshEntitlements() async {
        // Avoid false offline warnings at startup: NWPathMonitor.currentPath can be
        // stale/unspecified until the first async path callback arrives.
        let hasConfirmedPath = hasConfirmedNetworkPath
        let wasOffline = hasConfirmedPath ? !isNetworkReachable : false
        await purchaseManager.checkEntitlement()
        cachedEntitlements = purchaseManager.entitledProductIDs.union(locallyVerifiedProductIDs)
        isLoaded = true

        // Show the offline warning only if we got no entitlements AND we were
        // offline when we checked. If the user genuinely hasn't bought anything,
        // we don't show a false warning (the warning clears when we go online).
        if hasConfirmedPath && wasOffline && cachedEntitlements.isEmpty {
            showOfflinePurchaseWarning = true
        } else {
            showOfflinePurchaseWarning = false
        }
        
        #if DEBUG
        print("📦 [EntitlementManager] Loaded entitlements: \(cachedEntitlements) (offline=\(wasOffline), pathConfirmed=\(hasConfirmedPath))")
        #endif
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let reachable = path.status.isReachable
            Task { @MainActor in
                self.hasConfirmedNetworkPath = true
                self.isNetworkReachable = reachable
            }
            // If we just got connectivity and we're still showing the warning,
            // re-verify entitlements on the main actor so the UI updates.
            if reachable {
                Task { @MainActor in
                    guard self.showOfflinePurchaseWarning else { return }
                    #if DEBUG
                    print("🌐 [EntitlementManager] Connection restored — re-verifying entitlements")
                    #endif
                    await self.refreshEntitlements()
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Purchase Status Checks
    
    /// Check if a specific product is purchased
    func isModulePurchased(_ product: WSPProduct) -> Bool {
#if DEBUG
        if isPaywallCaptureModeEnabled {
            return false
        }
#endif
        // If entitlements haven't loaded yet, assume purchased to avoid
        // false blocks while the async StoreKit check is still in-flight.
        guard isLoaded else {
            return true
        }
        // Check cached entitlements first (includes locally verified purchases
        // that Transaction.currentEntitlements may not yet reflect on iOS).
        let cachedBundle = cachedEntitlements.contains(WSPProduct.allInBundle.rawValue)
        let cachedProduct = cachedEntitlements.contains(product.rawValue)
        // Also check the purchase manager directly as a fallback
        let bundleEntitled = cachedBundle || purchaseManager.isEntitled(to: WSPProduct.allInBundle.rawValue)
        let productEntitled = cachedProduct || purchaseManager.isEntitled(to: product.rawValue)
        return bundleEntitled || productEntitled
    }
    
    /// Check if a project type is unlocked (purchased or bundle)
    func isProjectTypeUnlocked(_ type: ProjectType) -> Bool {
        let product = WSPProduct.product(for: type)
        return isModulePurchased(product)
    }
    
    /// Check if user has any purchases
    var hasAnyPurchase: Bool {
#if DEBUG
        if isPaywallCaptureModeEnabled {
            return false
        }
#endif
        return !purchaseManager.entitledProductIDs.isEmpty
    }
    
    /// Check if user has purchased the full bundle
    var hasBundle: Bool {
#if DEBUG
        if isPaywallCaptureModeEnabled {
            return false
        }
#endif
        return purchaseManager.isEntitled(to: WSPProduct.allInBundle.rawValue)
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
    
    // MARK: - Verified Purchase Recording

    /// Record a product ID from a verified StoreKit transaction.
    /// This ensures the entitlement is recognised immediately, even if
    /// Transaction.currentEntitlements hasn't caught up yet (iOS timing issue).
    func recordVerifiedPurchase(_ productID: String) {
        locallyVerifiedProductIDs.insert(productID)
        cachedEntitlements.insert(productID)
        #if DEBUG
        print("✅ [EntitlementManager] Recorded verified purchase: \(productID), cachedEntitlements=\(cachedEntitlements)")
        #endif
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

// MARK: - NWPath.Status convenience

private extension NWPath.Status {
    var isReachable: Bool { self == .satisfied }
}
