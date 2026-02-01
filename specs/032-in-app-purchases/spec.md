# Feature 032: In-App Purchases

**Status:** Planning  
**Branch:** TBD  
**Date:** 2026-02-01

## Overview

Writing Shed Pro gives users access to the prose, poetry, fiction and drama features via the in-app purchase mechanism supported by StoreKit2. The package StoreKitManager provides access to the StoreKit (see the package ReadMe document). 
There are five in app purchases:
1. Prose Writer (id: com.writingshedpro.prosewriter)
2. Poetry Writer (id: com.writingshedpro.poetrywriter)
3. Fiction Writer (id: com.writingshedpro.fictionwriter)
4. Drama Writer (id: com.writingshedpro.dramawriter)
5. All-in Bundle (id: com.writingshedpro.allinbundle)
The app needs to add functions to use the StoreKitManager to enable the user to purchase modules. The app must also allow the user to use a reduced set of functions for free. They should be allowed to create at most one project of each type and one text file/scene for each project. Printing and exporting work should be blocked. At any point in time they should be able to purchase a module. If the all-in one bundle is purchased they should be able to use everything. 
---

## Requirements

### Functional Requirements

#### FR-1: Purchase Flow
- [ ] FR-1.1: Display available products from App Store Connect
- [ ] FR-1.2: Handle purchase transactions
- [ ] FR-1.3: Restore previous purchases
- [ ] FR-1.4: Handle purchase failures gracefully
- [ ] FR-1.5: Support Family Sharing (if applicable)

#### FR-2: Product Types
- [ ] FR-2.1: Support non-consumable purchases (one-time unlock)
- [ ] FR-2.2: Handle individual module purchases (Prose, Poetry, Fiction, Drama)
- [ ] FR-2.3: Handle All-in Bundle purchase (unlocks all modules)
- [ ] FR-2.4: If user owns individual modules and purchases bundle, handle gracefully

#### FR-3: Entitlements
- [ ] FR-3.1: Track purchased features/content
- [ ] FR-3.2: Gate premium features based on purchase status
- [ ] FR-3.3: Persist entitlements across app launches
- [ ] FR-3.4: Sync entitlements via iCloud/CloudKit

#### FR-4: UI/UX
- [ ] FR-4.1: Paywall/upgrade screen design
- [ ] FR-4.2: Display prices in user's local currency
- [ ] FR-4.3: Provide "Restore Purchases" button
- [ ] FR-4.4: Loading states during purchase flow
- [ ] FR-4.5: Show owned/available modules clearly

#### FR-5: Free Tier Limits
- [ ] FR-5.1: Allow maximum 1 project per project type (Prose, Poetry, Fiction, Drama)
- [ ] FR-5.2: Allow maximum 1 text file/scene per project
- [ ] FR-5.3: Block printing functionality for unpurchased modules
- [ ] FR-5.4: Block export functionality for unpurchased modules
- [ ] FR-5.5: Display clear messaging when limits are reached

#### FR-6: Upgrade Prompts
- [ ] FR-6.1: Show upgrade prompt when user tries to create second project
- [ ] FR-6.2: Show upgrade prompt when user tries to create second file/scene
- [ ] FR-6.3: Show upgrade prompt when user tries to print without purchase
- [ ] FR-6.4: Show upgrade prompt when user tries to export without purchase
- [ ] FR-6.5: Provide quick path to purchase from upgrade prompts

### Non-Functional Requirements

#### NFR-1: App Store Guidelines
- [ ] NFR-1.1: Comply with App Store Review Guidelines 3.1.1-3.1.3
- [ ] NFR-1.2: Link to Terms of Use and Privacy Policy
- [ ] NFR-1.3: Clearly describe what each purchase unlocks

#### NFR-2: Security
- [ ] NFR-2.1: Validate receipts (on-device or server-side)
- [ ] NFR-2.2: Prevent purchase bypass/tampering

#### NFR-3: Reliability
- [ ] NFR-3.1: Handle interrupted purchases
- [ ] NFR-3.2: Queue transactions for retry on failure
- [ ] NFR-3.3: Support offline entitlement checks

---

## Technical Design

### StoreKitManager Integration

The app uses the `StoreKitManager` package for all StoreKit 2 interactions.

```swift
import StoreKitManager

// MARK: - Product Identifiers

enum WSPProduct: String, CaseIterable {
    case proseWriter = "com.writingshedpro.prosewriter"
    case poetryWriter = "com.writingshedpro.poetrywriter"
    case fictionWriter = "com.writingshedpro.fictionwriter"
    case dramaWriter = "com.writingshedpro.dramawriter"
    case allInBundle = "com.writingshedpro.allinbundle"
    
    static var allProductIDs: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
    
    var projectType: ProjectType? {
        switch self {
        case .proseWriter: return .prose
        case .poetryWriter: return .poetry
        case .fictionWriter: return .fiction
        case .dramaWriter: return .drama
        case .allInBundle: return nil  // Unlocks all
        }
    }
}
```

### Entitlement Checking

```swift
import StoreKitManager

@Observable
class EntitlementManager {
    private let storeKitManager: StoreKitManager
    
    init(storeKitManager: StoreKitManager) {
        self.storeKitManager = storeKitManager
    }
    
    // MARK: - Purchase Status
    
    func isModulePurchased(_ product: WSPProduct) -> Bool {
        if storeKitManager.isPurchased(WSPProduct.allInBundle.rawValue) {
            return true  // Bundle unlocks everything
        }
        return storeKitManager.isPurchased(product.rawValue)
    }
    
    func isProjectTypeUnlocked(_ type: ProjectType) -> Bool {
        switch type {
        case .prose: return isModulePurchased(.proseWriter)
        case .poetry: return isModulePurchased(.poetryWriter)
        case .fiction: return isModulePurchased(.fictionWriter)
        case .drama: return isModulePurchased(.dramaWriter)
        }
    }
    
    // MARK: - Free Tier Limits
    
    func canCreateProject(ofType type: ProjectType, existingCount: Int) -> Bool {
        if isProjectTypeUnlocked(type) {
            return true  // No limit if purchased
        }
        return existingCount < 1  // Free tier: max 1 project per type
    }
    
    func canCreateFile(inProject project: Project, existingCount: Int) -> Bool {
        if isProjectTypeUnlocked(project.projectType) {
            return true  // No limit if purchased
        }
        return existingCount < 1  // Free tier: max 1 file per project
    }
    
    func canExport(project: Project) -> Bool {
        return isProjectTypeUnlocked(project.projectType)
    }
    
    func canPrint(project: Project) -> Bool {
        return isProjectTypeUnlocked(project.projectType)
    }
}
```

### Purchase Flow

```swift
// Trigger purchase via StoreKitManager
func purchaseModule(_ product: WSPProduct) async throws {
    try await storeKitManager.purchase(product.rawValue)
}

// Restore purchases
func restorePurchases() async {
    await storeKitManager.restorePurchases()
}
```

---

## Products

| Product ID | Type | Description |
|------------|------|-------------|
| com.writingshedpro.prosewriter | Non-consumable | Unlocks unlimited Prose projects and files, plus export/print |
| com.writingshedpro.poetrywriter | Non-consumable | Unlocks unlimited Poetry projects and files, plus export/print |
| com.writingshedpro.fictionwriter | Non-consumable | Unlocks unlimited Fiction projects and files, plus export/print |
| com.writingshedpro.dramawriter | Non-consumable | Unlocks unlimited Drama projects and files, plus export/print |
| com.writingshedpro.allinbundle | Non-consumable | Unlocks all modules (best value) |

---

## UI Screens

### Store/Upgrade Screen
- Hero image/illustration for Writing Shed Pro
- Module cards showing each purchasable module:
  - Module name and icon
  - Features included
  - Price (localized)
  - "Purchased" badge if owned
  - Buy button if not owned
- All-in Bundle featured prominently (best value)
- Restore purchases link
- Terms of Use / Privacy Policy links

### Upgrade Prompt Sheet
- Shown when user hits free tier limit
- Explains what they're trying to do
- Shows relevant module to purchase
- Option to see all modules (full store)
- Dismiss button

### Settings Integration
- "Manage Purchases" row
- Shows owned modules with checkmarks
- Restore purchases option
- Link to full store for additional purchases

---

## Testing

### Test Cases - Purchase Flow
- [ ] TC-1: Individual module purchase completes successfully
- [ ] TC-2: All-in Bundle purchase completes successfully
- [ ] TC-3: Restore purchases recovers all owned modules
- [ ] TC-4: Cancelled purchase handled gracefully
- [ ] TC-5: Failed purchase shows error message
- [ ] TC-6: Entitlements persist after app restart

### Test Cases - Free Tier Limits
- [ ] TC-7: User can create 1 project per type for free
- [ ] TC-8: User cannot create 2nd project without purchase
- [ ] TC-9: User can create 1 file per free project
- [ ] TC-10: User cannot create 2nd file without purchase
- [ ] TC-11: Export blocked for unpurchased modules
- [ ] TC-12: Print blocked for unpurchased modules
- [ ] TC-13: Upgrade prompt shown when hitting limits

### Test Cases - Module Unlocking
- [ ] TC-14: Purchasing Prose unlocks unlimited Prose projects/files
- [ ] TC-15: Purchasing bundle unlocks all project types
- [ ] TC-16: Purchasing bundle after individual modules works correctly
- [ ] TC-17: Export enabled after purchase
- [ ] TC-18: Print enabled after purchase

### Sandbox Testing
- Use sandbox App Store account
- Test all purchase scenarios
- Test Family Sharing if enabled
- Verify StoreKitManager integration

---

## App Store Connect Setup

1. Create products in App Store Connect
2. Configure pricing
3. Add product descriptions and screenshots
4. Submit for review with app update

---

## References

- [StoreKit 2 Documentation](https://developer.apple.com/documentation/storekit)
- [App Store Review Guidelines - In-App Purchase](https://developer.apple.com/app-store/review/guidelines/#in-app-purchase)
- [Implementing a Store in Your App](https://developer.apple.com/documentation/storekit/in-app_purchase/implementing_a_store_in_your_app_using_the_storekit_api)
