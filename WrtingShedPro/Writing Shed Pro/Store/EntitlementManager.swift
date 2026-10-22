//
//  EntitlementManager.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import Foundation
import Network
import StoreKit
import SwiftData
import StoreKitManager
import Observation

enum PurchaseModel: String, Equatable {
    case legacy
    case trialAndFullAccess
}

enum OriginalAppVersionScheme {
    case marketingVersion
    case buildNumber
}

enum ProjectImportAccess: Equatable {
    case allowed
    case projectLimit
    case fileLimit
}

enum CoreAccessState: Equatable {
    case loading
    case activationRequired
    case trialActive(expiresAt: Date)
    case trialExpired
    case fullAccess
    case legacy

    var allowsCoreMutations: Bool {
        switch self {
        case .trialActive, .fullAccess, .legacy:
            return true
        case .loading, .activationRequired, .trialExpired:
            return false
        }
    }

    var allowsAppEntry: Bool {
        switch self {
        case .trialActive, .trialExpired, .fullAccess, .legacy:
            return true
        case .loading, .activationRequired:
            return false
        }
    }
}

enum EntitlementPolicy {
    static let cutoverVersion = "19.0"
    static let cutoverBuildNumber = "503"
    static let trialDuration: TimeInterval = 10 * 24 * 60 * 60

    static func purchaseModel(
        for originalAppVersion: String,
        versionScheme: OriginalAppVersionScheme = .marketingVersion
    ) -> PurchaseModel {
        let cutover = versionScheme == .buildNumber ? cutoverBuildNumber : cutoverVersion
        return compareVersions(originalAppVersion, cutover) == .orderedAscending
            ? .legacy
            : .trialAndFullAccess
    }

    static func purchaseModel(
        for originalAppVersion: String,
        isSandboxEnvironment: Bool,
        versionScheme: OriginalAppVersionScheme = .marketingVersion
    ) -> PurchaseModel {
        isSandboxEnvironment
            ? .trialAndFullAccess
            : purchaseModel(for: originalAppVersion, versionScheme: versionScheme)
    }

    static func purchaseModel(
        appTransactionModel: PurchaseModel?,
        entitlementIDs: Set<String>
    ) -> PurchaseModel? {
        let legacyProductIDs = Set(WSPProduct.legacyCoreProducts.map(\.rawValue))
        if !entitlementIDs.isDisjoint(with: legacyProductIDs) {
            return .legacy
        }
        return appTransactionModel
    }

    static func coreAccessState(
        purchaseModel: PurchaseModel?,
        entitlementIDs: Set<String>,
        trialStartDate: Date?,
        now: Date
    ) -> CoreAccessState {
        if entitlementIDs.contains(WSPProduct.fullAccess.rawValue) {
            return .fullAccess
        }

        guard let purchaseModel else { return .loading }
        guard purchaseModel == .trialAndFullAccess else { return .legacy }

        guard entitlementIDs.contains(WSPProduct.tenDayTrial.rawValue),
              let trialStartDate else {
            return .activationRequired
        }

        let expirationDate = trialStartDate.addingTimeInterval(trialDuration)
        return now < expirationDate ? .trialActive(expiresAt: expirationDate) : .trialExpired
    }

    static func canCreate(
        existingCount: Int,
        freeTierLimit: Int,
        purchaseModel: PurchaseModel?,
        coreAccessState: CoreAccessState,
        isLegacyProductUnlocked: Bool
    ) -> Bool {
        if coreAccessState == .fullAccess { return true }
        if purchaseModel == .trialAndFullAccess {
            return coreAccessState.allowsCoreMutations
        }
        return isLegacyProductUnlocked || existingCount < freeTierLimit
    }

    static func isModulePurchased(
        _ product: WSPProduct,
        purchaseModel: PurchaseModel?,
        coreAccessState: CoreAccessState,
        entitlementIDs: Set<String>
    ) -> Bool {
        if WSPProduct.legacyCoreProducts.contains(product) {
            if coreAccessState == .fullAccess { return true }
            if purchaseModel == .trialAndFullAccess {
                return coreAccessState.allowsCoreMutations
            }
            return entitlementIDs.contains(WSPProduct.allInBundle.rawValue)
                || entitlementIDs.contains(product.rawValue)
        }
        return entitlementIDs.contains(product.rawValue)
    }

    static func projectImportAccess(
        existingProjectCount: Int,
        importedFileCount: Int,
        projectLimit: Int,
        fileLimit: Int,
        purchaseModel: PurchaseModel?,
        coreAccessState: CoreAccessState,
        isLegacyProductUnlocked: Bool
    ) -> ProjectImportAccess {
        guard canCreate(
            existingCount: existingProjectCount,
            freeTierLimit: projectLimit,
            purchaseModel: purchaseModel,
            coreAccessState: coreAccessState,
            isLegacyProductUnlocked: isLegacyProductUnlocked
        ) else {
            return .projectLimit
        }

        guard importedFileCount == 0 || canCreate(
            existingCount: importedFileCount - 1,
            freeTierLimit: fileLimit,
            purchaseModel: purchaseModel,
            coreAccessState: coreAccessState,
            isLegacyProductUnlocked: isLegacyProductUnlocked
        ) else {
            return .fileLimit
        }

        return .allowed
    }

    static func canPurchaseManuscriptAnalyst(
        purchaseModel: PurchaseModel?,
        coreAccessState: CoreAccessState
    ) -> Bool {
        guard let purchaseModel else { return false }
        switch purchaseModel {
        case .legacy:
            return true
        case .trialAndFullAccess:
            return coreAccessState == .fullAccess
        }
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lhsComponents = numericComponents(lhs)
        let rhsComponents = numericComponents(rhs)
        let componentCount = max(lhsComponents.count, rhsComponents.count)

        for index in 0..<componentCount {
            let lhsValue = index < lhsComponents.count ? lhsComponents[index] : 0
            let rhsValue = index < rhsComponents.count ? rhsComponents[index] : 0
            if lhsValue < rhsValue { return .orderedAscending }
            if lhsValue > rhsValue { return .orderedDescending }
        }
        return .orderedSame
    }

    private static func numericComponents(_ version: String) -> [Int] {
        version.split(separator: ".").map { component in
            Int(component.prefix(while: { $0.isNumber })) ?? 0
        }
    }
}

// MARK: - Entitlement Manager

/// Manages purchase entitlements and free tier gating for Writing Shed Pro.
/// Uses StoreKitManager package for all StoreKit 2 interactions.
@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
@Observable
@MainActor
final class EntitlementManager {

    private enum PersistenceKey {
        static let purchaseModel = "iap.purchaseModel"
        static let trialStartDate = "iap.trialStartDate"
        static let latestTrustedDate = "iap.latestTrustedDate"
    }

    private struct VerifiedEntitlementSnapshot {
        var productIDs: Set<String> = []
        var trialStartDate: Date?
    }
    
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

    /// Purchase model derived from Apple's verified original app version.
    private(set) var purchaseModel: PurchaseModel?

    /// Authoritative start of the non-consumable trial transaction.
    private(set) var trialStartDate: Date?

    /// Latest trusted wall-clock value, used to prevent clock rollback extending a trial.
    private(set) var latestTrustedDate: Date?

    /// Updated by the foreground lifecycle so computed trial state changes at expiry.
    private(set) var currentEvaluationDate: Date = Date()

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

#if DEBUG || targetEnvironment(simulator)
    private static let paywallCaptureModeKey = "debug.paywallCaptureMode"
#endif
#if DEBUG
    private(set) var isExpiredTrialSimulationEnabled = false
#endif
    
    // MARK: - Initialization
    
    private init() {
#if targetEnvironment(simulator)
        if UserDefaults.standard.object(forKey: Self.paywallCaptureModeKey) == nil {
            UserDefaults.standard.set(true, forKey: Self.paywallCaptureModeKey)
        }
#endif
        if let rawValue = UserDefaults.standard.string(forKey: PersistenceKey.purchaseModel) {
            purchaseModel = PurchaseModel(rawValue: rawValue)
        }
        trialStartDate = UserDefaults.standard.object(forKey: PersistenceKey.trialStartDate) as? Date
        latestTrustedDate = UserDefaults.standard.object(forKey: PersistenceKey.latestTrustedDate) as? Date
    #if DEBUG
        UserDefaults.standard.removeObject(forKey: "debug.expiredTrialSimulation")
    #endif
    }

#if DEBUG || targetEnvironment(simulator)
    var isPaywallCaptureModeEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.paywallCaptureModeKey)
    }

    func setPaywallCaptureModeEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: Self.paywallCaptureModeKey)
        if enabled {
            locallyVerifiedProductIDs.removeAll()
            purchaseModel = .trialAndFullAccess
        } else {
            await resolvePurchaseModel()
        }
        await refreshEntitlements()
    }

    func resetPaywallCaptureState() async {
        UserDefaults.standard.removeObject(forKey: Self.paywallCaptureModeKey)
        locallyVerifiedProductIDs.removeAll()
        await resolvePurchaseModel()
        await refreshEntitlements()
    }
#endif

#if DEBUG
    func setExpiredTrialSimulationEnabled(_ enabled: Bool) {
        if enabled, let trialStartDate {
            let trialIdentifier = String(Int(trialStartDate.timeIntervalSince1970))
            UserDefaults.standard.removeObject(
                forKey: "iap.trial.warning.\(trialIdentifier).expired"
            )
        }
        isExpiredTrialSimulationEnabled = enabled
        refreshTimeState()
    }
#endif
    
    // MARK: - Setup
    
    /// Configure the manager and load initial entitlements
    func configure() async {
        startNetworkMonitoring()
        // Configure StoreKitPurchaseManager with the subscription config so it
        // starts the transaction listener and registers valid product IDs.
        if let config = SubscriptionConfigLoader.loadLocalizedConfig() {
            purchaseManager.configure(from: config)
        }
        await resolvePurchaseModel()
#if DEBUG || targetEnvironment(simulator)
        if isPaywallCaptureModeEnabled {
            purchaseModel = .trialAndFullAccess
        }
#endif
        await refreshEntitlements()
    }
    
    /// Refresh entitlements from StoreKit
    func refreshEntitlements(refreshPurchaseModel: Bool = false) async {
        if refreshPurchaseModel {
            await resolvePurchaseModel()
        }
        // Avoid false offline warnings at startup: NWPathMonitor.currentPath can be
        // stale/unspecified until the first async path callback arrives.
        let hasConfirmedPath = hasConfirmedNetworkPath
        let wasOffline = hasConfirmedPath ? !isNetworkReachable : false
        await purchaseManager.checkEntitlement()
        let verifiedSnapshot = await loadCurrentEntitlements()
        let verifiedEntitlements = verifiedSnapshot.productIDs
#if DEBUG || targetEnvironment(simulator)
        if isPaywallCaptureModeEnabled {
            cachedEntitlements = locallyVerifiedProductIDs
        } else {
            cachedEntitlements = verifiedEntitlements.union(locallyVerifiedProductIDs)
        }
#else
        cachedEntitlements = verifiedEntitlements.union(locallyVerifiedProductIDs)
#endif
        let reconciledPurchaseModel = EntitlementPolicy.purchaseModel(
            appTransactionModel: purchaseModel,
            entitlementIDs: cachedEntitlements
        )
        if reconciledPurchaseModel != purchaseModel {
            purchaseModel = reconciledPurchaseModel
            if let reconciledPurchaseModel {
                UserDefaults.standard.set(
                    reconciledPurchaseModel.rawValue,
                    forKey: PersistenceKey.purchaseModel
                )
            }
        }
    if let verifiedTrialStartDate = verifiedSnapshot.trialStartDate {
        recordTrialStartDate(verifiedTrialStartDate)
    }
    if !wasOffline {
        recordTrustedDate(Date())
    }
        isLoaded = true

        // Show the offline warning only if we got no entitlements AND we were
        // offline when we checked. If the user genuinely hasn't bought anything,
        // we don't show a false warning (the warning clears when we go online).
        if hasConfirmedPath && wasOffline && cachedEntitlements.isEmpty {
            showOfflinePurchaseWarning = true
        } else {
            showOfflinePurchaseWarning = false
        }

        Task {
            await SalesReporter.reconcileCurrentEntitlements()
        }
        
        #if DEBUG
        print("📦 [EntitlementManager] Loaded entitlements: \(cachedEntitlements) (storeKitManager=\(purchaseManager.entitledProductIDs), offline=\(wasOffline), pathConfirmed=\(hasConfirmedPath))")
        #endif
    }

    private func loadCurrentEntitlements() async -> VerifiedEntitlementSnapshot {
        var snapshot = VerifiedEntitlementSnapshot()
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            includeVerifiedTransaction(transaction, in: &snapshot)
        }

        let trialProductID = WSPProduct.tenDayTrial.rawValue
        if !snapshot.productIDs.contains(trialProductID),
           let latestTrialResult = await Transaction.latest(for: trialProductID),
           case .verified(let transaction) = latestTrialResult {
            includeVerifiedTransaction(transaction, in: &snapshot)
            #if DEBUG
            if snapshot.productIDs.contains(trialProductID) {
                print("📦 [EntitlementManager] Recovered trial from latest StoreKit transaction")
            }
            #endif
        }
        return snapshot
    }

    private func includeVerifiedTransaction(
        _ transaction: Transaction,
        in snapshot: inout VerifiedEntitlementSnapshot
    ) {
        guard WSPProduct.allProductIDs.contains(transaction.productID) else { return }
        guard transaction.revocationDate == nil else { return }
        if let expirationDate = transaction.expirationDate, expirationDate <= Date() { return }

        snapshot.productIDs.insert(transaction.productID)
        if transaction.productID == WSPProduct.tenDayTrial.rawValue {
            let purchaseDate = transaction.originalPurchaseDate
            snapshot.trialStartDate = min(snapshot.trialStartDate ?? purchaseDate, purchaseDate)
        }
    }

    private func resolvePurchaseModel() async {
        do {
            switch try await AppTransaction.shared {
            case .verified(let appTransaction):
                #if os(macOS) && !targetEnvironment(macCatalyst)
                let versionScheme = OriginalAppVersionScheme.marketingVersion
                #else
                let versionScheme = OriginalAppVersionScheme.buildNumber
                #endif
                let resolvedModel = EntitlementPolicy.purchaseModel(
                    for: appTransaction.originalAppVersion,
                    isSandboxEnvironment: appTransaction.environment != .production,
                    versionScheme: versionScheme
                )
                purchaseModel = resolvedModel
                UserDefaults.standard.set(resolvedModel.rawValue, forKey: PersistenceKey.purchaseModel)
            case .unverified:
                break
            }
        } catch {
            #if DEBUG
            print("⚠️ [EntitlementManager] Unable to resolve original app transaction: \(error.localizedDescription)")
            #endif
        }
    }

    private func recordTrialStartDate(_ date: Date) {
        let authoritativeDate = min(trialStartDate ?? date, date)
        trialStartDate = authoritativeDate
        UserDefaults.standard.set(authoritativeDate, forKey: PersistenceKey.trialStartDate)
    }

    private func recordTrustedDate(_ date: Date) {
        let trustedDate = max(latestTrustedDate ?? date, date)
        latestTrustedDate = trustedDate
        UserDefaults.standard.set(trustedDate, forKey: PersistenceKey.latestTrustedDate)
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

    var coreAccessState: CoreAccessState {
#if DEBUG
        if isExpiredTrialSimulationEnabled {
            return .trialExpired
        }
#endif
    return EntitlementPolicy.coreAccessState(
            purchaseModel: purchaseModel,
            entitlementIDs: cachedEntitlements,
            trialStartDate: trialStartDate,
            now: max(currentEvaluationDate, latestTrustedDate ?? .distantPast)
        )
    }

    var trialExpirationDate: Date? {
#if DEBUG
        if isExpiredTrialSimulationEnabled {
            return currentEvaluationDate
        }
#endif
        guard purchaseModel == .trialAndFullAccess, let trialStartDate else { return nil }
        return trialStartDate.addingTimeInterval(EntitlementPolicy.trialDuration)
    }

    var trialTimeRemaining: TimeInterval? {
        guard let trialExpirationDate else { return nil }
        return max(0, trialExpirationDate.timeIntervalSince(max(currentEvaluationDate, latestTrustedDate ?? .distantPast)))
    }

    func refreshTimeState() {
        currentEvaluationDate = Date()
    }

    var requiresTrialActivation: Bool {
        coreAccessState == .activationRequired
    }

    var hasActivatedTrial: Bool {
        cachedEntitlements.contains(WSPProduct.tenDayTrial.rawValue)
    }

    var isCoreReadOnly: Bool {
        coreAccessState == .trialExpired
    }

    var hasFullAccess: Bool {
        coreAccessState == .fullAccess
    }

    var trialStatusText: String? {
        switch coreAccessState {
        case .trialActive:
            guard let trialTimeRemaining else { return nil }
            if trialTimeRemaining <= 24 * 60 * 60 {
                return NSLocalizedString("iap.trial.lessThanOneDay", comment: "Less than one trial day remains")
            }
            let days = Int(ceil(trialTimeRemaining / (24 * 60 * 60)))
            return String(
                format: NSLocalizedString("iap.trial.daysRemaining", comment: "Trial days remaining"),
                days
            )
        case .trialExpired:
            return NSLocalizedString("iap.trial.expired", comment: "Trial expired")
        default:
            return nil
        }
    }

    var canModifyContent: Bool {
        coreAccessState.allowsCoreMutations
    }
    
    /// Check if a specific product is purchased
    func isModulePurchased(_ product: WSPProduct) -> Bool {
        // Until StoreKit has reported entitlements, do not mark products owned.
        guard isLoaded else {
            return false
        }
        return EntitlementPolicy.isModulePurchased(
            product,
            purchaseModel: purchaseModel,
            coreAccessState: coreAccessState,
            entitlementIDs: cachedEntitlements
        )
    }
    
    /// Check if a project type is unlocked (purchased or bundle)
    func isProjectTypeUnlocked(_ type: ProjectType) -> Bool {
        let product = WSPProduct.product(for: type)
        return isModulePurchased(product)
    }
    
    /// Check if user has any purchases
    var hasAnyPurchase: Bool {
        return !cachedEntitlements.isEmpty
    }
    
    /// Check if user has purchased the full bundle
    var hasBundle: Bool {
        return cachedEntitlements.contains(WSPProduct.allInBundle.rawValue)
    }
    
    /// Check if user has purchased at least one individual module (not via bundle)
    var hasAnyIndividualModulePurchase: Bool {
        guard !hasBundle else { return false }  // Bundle doesn't count as individual
        return WSPProduct.individualModules.contains { product in
            cachedEntitlements.contains(product.rawValue)
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

    func recordVerifiedPurchase(_ transaction: Transaction) {
        guard transaction.revocationDate == nil else {
            locallyVerifiedProductIDs.remove(transaction.productID)
            cachedEntitlements.remove(transaction.productID)
            return
        }
        recordVerifiedPurchase(transaction.productID)
        if transaction.productID == WSPProduct.tenDayTrial.rawValue {
            recordTrialStartDate(transaction.originalPurchaseDate)
        }
        recordTrustedDate(Date())
    }

    // MARK: - Free Tier Limit Checks
    
    /// Check if user can create a new project of the given type
    /// - Parameters:
    ///   - type: The project type to create
    ///   - existingCount: Number of existing projects of this type
    /// - Returns: true if allowed, false if limit reached
    func canCreateProject(ofType type: ProjectType, existingCount: Int) -> Bool {
        // Fail closed for creation limits until entitlements are loaded.
        // This prevents a startup race where users can bypass free-tier gates
        // before StoreKit has finished loading entitlement state.
        guard isLoaded else {
            return existingCount < Self.freeTierMaxProjectsPerType
        }

        return EntitlementPolicy.canCreate(
            existingCount: existingCount,
            freeTierLimit: Self.freeTierMaxProjectsPerType,
            purchaseModel: purchaseModel,
            coreAccessState: coreAccessState,
            isLegacyProductUnlocked: isProjectTypeUnlocked(type)
        )
    }
    
    /// Check if user can create a new file in the given project
    /// - Parameters:
    ///   - projectType: The type of the parent project
    ///   - existingCount: Number of existing files in the project
    /// - Returns: true if allowed, false if limit reached
    func canCreateFile(forProjectType projectType: ProjectType, existingCount: Int) -> Bool {
        // Fail closed for creation limits until entitlements are loaded.
        guard isLoaded else {
            return existingCount < Self.freeTierMaxFilesPerProject
        }

        return EntitlementPolicy.canCreate(
            existingCount: existingCount,
            freeTierLimit: Self.freeTierMaxFilesPerProject,
            purchaseModel: purchaseModel,
            coreAccessState: coreAccessState,
            isLegacyProductUnlocked: isProjectTypeUnlocked(projectType)
        )
    }

    func projectImportAccess(
        projectType: ProjectType,
        existingProjectCount: Int,
        importedFileCount: Int
    ) -> ProjectImportAccess {
        EntitlementPolicy.projectImportAccess(
            existingProjectCount: existingProjectCount,
            importedFileCount: importedFileCount,
            projectLimit: Self.freeTierMaxProjectsPerType,
            fileLimit: Self.freeTierMaxFilesPerProject,
            purchaseModel: purchaseModel,
            coreAccessState: coreAccessState,
            isLegacyProductUnlocked: isProjectTypeUnlocked(projectType)
        )
    }
    
    /// Check if user can export from a project of the given type
    func canExport(projectType: ProjectType) -> Bool {
        if purchaseModel == .trialAndFullAccess {
            return coreAccessState.allowsCoreMutations
        }
        return isProjectTypeUnlocked(projectType)
    }
    
    /// Check if user can print from a project of the given type
    func canPrint(projectType: ProjectType) -> Bool {
        if purchaseModel == .trialAndFullAccess {
            return coreAccessState.allowsCoreMutations
        }
        return isProjectTypeUnlocked(projectType)
    }

    /// Check if user has active Manuscript Analyst subscription
    func isManuscriptAnalystSubscriptionActive() -> Bool {
        // Until StoreKit has reported entitlements, do not mark subscriptions active.
        guard isLoaded else {
            return false
        }
        // Check if the subscription product is in cached entitlements
        let subscriptionProductID = WSPProduct.manuscriptAnalystSubscription.rawValue
        return cachedEntitlements.contains(subscriptionProductID)
    }

    func canUseManuscriptAnalyst() -> Bool {
        guard isManuscriptAnalystSubscriptionActive() else { return false }
        guard purchaseModel == .trialAndFullAccess else { return true }
        return hasFullAccess
    }

    var canPurchaseManuscriptAnalyst: Bool {
        EntitlementPolicy.canPurchaseManuscriptAnalyst(
            purchaseModel: purchaseModel,
            coreAccessState: coreAccessState
        )
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
        .fullAccess
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
