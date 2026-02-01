# Feature 032: In-App Purchases - Implementation Plan

## Overview

This plan outlines the implementation of in-app purchases for Writing Shed Pro. Since the `StoreKitManager` package handles all StoreKit 2 interactions, this is primarily an integration and UI gating task.

**Estimated Duration:** 1-2 weeks  
**Dependencies:** StoreKitManager package (already integrated)

---

## Implementation Phases

### Phase 1: Core Infrastructure (Days 1-2)
**Goal:** Set up product definitions and entitlement manager

#### Task 1.1: Product Definitions
- [ ] Create `WSPProduct.swift` with product enum
- [ ] Define all 5 product IDs
- [ ] Add helper computed properties (projectType mapping)
- [ ] Add `allProductIDs` static property
- [ ] Add unit tests for product enum

**File:** `WrtingShedPro/Store/WSPProduct.swift`

#### Task 1.2: Entitlement Manager
- [ ] Create `EntitlementManager.swift`
- [ ] Inject `StoreKitManager` dependency
- [ ] Implement `isModulePurchased(_ product:)` 
- [ ] Implement `isProjectTypeUnlocked(_ type:)`
- [ ] Handle bundle logic (bundle unlocks all)
- [ ] Add unit tests with mock StoreKitManager

**File:** `WrtingShedPro/Store/EntitlementManager.swift`

#### Task 1.3: App Integration
- [ ] Add `EntitlementManager` to app's environment
- [ ] Initialize StoreKitManager with product IDs at app launch
- [ ] Load products on app startup
- [ ] Listen for transaction updates
- [ ] Add to `Writing_Shed_ProApp.swift`

**File:** `WrtingShedPro/Writing_Shed_ProApp.swift`

---

### Phase 2: Free Tier Gating (Days 3-4)
**Goal:** Implement limits for unpurchased modules

#### Task 2.1: Project Count Limits
- [ ] Create helper to count projects by type
- [ ] Add `canCreateProject(ofType:existingCount:)` to EntitlementManager
- [ ] Modify project creation flow to check entitlement
- [ ] Show upgrade prompt if limit reached
- [ ] Add unit tests

**Files to modify:**
- `ProjectManager.swift` or equivalent
- `ProjectListView.swift` (or wherever "New Project" is triggered)

#### Task 2.2: File Count Limits
- [ ] Create helper to count files in project
- [ ] Add `canCreateFile(inProject:existingCount:)` to EntitlementManager
- [ ] Modify file creation flow to check entitlement
- [ ] Show upgrade prompt if limit reached
- [ ] Add unit tests

**Files to modify:**
- `FileManager.swift` or equivalent
- `FolderFilesView.swift` (or wherever "New File" is triggered)

#### Task 2.3: Export Gating
- [ ] Add `canExport(project:)` to EntitlementManager
- [ ] Modify export flow to check entitlement
- [ ] Show upgrade prompt if blocked
- [ ] Disable/dim export buttons for unpurchased modules
- [ ] Add unit tests

**Files to modify:**
- Export-related views and managers

#### Task 2.4: Print Gating
- [ ] Add `canPrint(project:)` to EntitlementManager
- [ ] Modify print flow to check entitlement
- [ ] Show upgrade prompt if blocked
- [ ] Disable/dim print buttons for unpurchased modules
- [ ] Add unit tests

**Files to modify:**
- Print-related views and managers

---

### Phase 3: Upgrade Prompt UI (Day 5)
**Goal:** Create reusable upgrade prompt sheet

#### Task 3.1: Upgrade Prompt View
- [ ] Create `UpgradePromptView.swift`
- [ ] Accept parameters: feature being blocked, relevant module
- [ ] Display what user tried to do
- [ ] Show module card with price
- [ ] Add "View All Modules" button
- [ ] Add "Not Now" dismiss button
- [ ] Style to match app design

**File:** `WrtingShedPro/Store/Views/UpgradePromptView.swift`

#### Task 3.2: Upgrade Prompt Presentation
- [ ] Create `@Observable` state for showing prompt
- [ ] Add `.sheet` modifier to root views
- [ ] Pass context (which limit was hit)
- [ ] Handle purchase completion (dismiss + refresh)

#### Task 3.3: Integration Points
- [ ] Wire up prompt to project creation limit
- [ ] Wire up prompt to file creation limit
- [ ] Wire up prompt to export limit
- [ ] Wire up prompt to print limit
- [ ] Test all prompt triggers

---

### Phase 4: Store UI (Days 6-7)
**Goal:** Full store screen for browsing and purchasing modules

#### Task 4.1: Store View
- [ ] Create `StoreView.swift`
- [ ] Fetch products from StoreKitManager
- [ ] Show loading state while fetching
- [ ] Display module cards in grid/list
- [ ] Feature bundle prominently (best value badge)
- [ ] Add Restore Purchases button
- [ ] Add Terms/Privacy links

**File:** `WrtingShedPro/Store/Views/StoreView.swift`

#### Task 4.2: Module Card Component
- [ ] Create `ModuleCardView.swift`
- [ ] Display module icon/image
- [ ] Display module name
- [ ] Display localized price
- [ ] Show "Purchased ✓" badge if owned
- [ ] Buy button triggers purchase flow
- [ ] Loading state during purchase

**File:** `WrtingShedPro/Store/Views/ModuleCardView.swift`

#### Task 4.3: Purchase Flow UI
- [ ] Show loading overlay during purchase
- [ ] Handle success (show confirmation, update UI)
- [ ] Handle cancellation (dismiss quietly)
- [ ] Handle failure (show error alert)
- [ ] Animate state changes

#### Task 4.4: Bundle Card
- [ ] Special styling for All-in Bundle
- [ ] Show "Best Value" or savings percentage
- [ ] List all included modules
- [ ] Prominent placement in store

---

### Phase 5: Settings Integration (Day 8)
**Goal:** Add purchase management to Settings

#### Task 5.1: Settings Row
- [ ] Add "Manage Purchases" row to Settings
- [ ] Show count of owned modules (e.g., "2 of 4 modules")
- [ ] Navigate to StoreView on tap

**File to modify:** `SettingsView.swift`

#### Task 5.2: Owned Modules Display
- [ ] Show list of owned modules with checkmarks
- [ ] Show available modules with prices
- [ ] Restore Purchases button in Settings
- [ ] Handle restore success/failure

---

### Phase 6: App Store Connect Setup (Day 9)
**Goal:** Configure products in App Store Connect

#### Task 6.1: Create Products
- [ ] Create `com.writingshedpro.prosewriter` (Non-consumable)
- [ ] Create `com.writingshedpro.poetrywriter` (Non-consumable)
- [ ] Create `com.writingshedpro.fictionwriter` (Non-consumable)
- [ ] Create `com.writingshedpro.dramawriter` (Non-consumable)
- [ ] Create `com.writingshedpro.allinbundle` (Non-consumable)

#### Task 6.2: Configure Each Product
- [ ] Set reference name
- [ ] Set product ID
- [ ] Set price tier
- [ ] Add display name (localized)
- [ ] Add description (localized)
- [ ] Add screenshot (for review)

#### Task 6.3: StoreKit Configuration File
- [ ] Create `Products.storekit` for local testing
- [ ] Add all 5 products with matching Product IDs
- [ ] Configure for sandbox testing
- [ ] Verify products load in simulator

**File:** `WrtingShedPro/Products.storekit`

#### Task 6.4: Xcode Scheme Configuration
- [ ] Edit Scheme (⌘<) → Run → Options → Set StoreKit Configuration to `Products.storekit`
- [ ] Edit Scheme → Archive → Options → Set StoreKit Configuration to **None**
- [ ] Verify local testing works in Simulator
- [ ] Document scheme settings for team

---

## ⚠️ StoreKit Configuration - Critical Setup

### Scheme Configuration (Often Forgotten!)

After creating `Products.storekit`, you **must** configure the Xcode scheme:

1. **Product → Scheme → Edit Scheme** (or ⌘<)
2. Select **Run** on the left
3. Go to **Options** tab
4. Set **StoreKit Configuration** to your `.storekit` file

### TestFlight/Production Gotcha

**For TestFlight and App Store builds, REMOVE the StoreKit Configuration!**

| Build Type | Scheme Section | StoreKit Config | Environment |
|------------|----------------|-----------------|-------------|
| Debug (Simulator) | Run → Options | `Products.storekit` | Local testing |
| Debug (Device) | Run → Options | `Products.storekit` | Local testing |
| TestFlight | Archive → Options | **None** | Sandbox |
| App Store | Archive → Options | **None** | Production |

**If you leave the StoreKit file configured for Archive, TestFlight builds will fail to load real products from App Store Connect!**

### Pre-Archive Checklist
- [ ] Edit Scheme → Archive → Options
- [ ] Verify StoreKit Configuration is set to **None**
- [ ] Products exist in App Store Connect
- [ ] Sandbox tester account ready

---

### Phase 7: Testing (Days 10-11)
**Goal:** Comprehensive testing of all purchase flows

#### Task 7.1: Unit Tests
- [ ] Test `WSPProduct` enum
- [ ] Test `EntitlementManager` with mock StoreKitManager
- [ ] Test free tier limit logic
- [ ] Test bundle unlocks all modules
- [ ] Test edge cases (empty state, all purchased, etc.)

#### Task 7.2: Integration Tests
- [ ] Test product loading
- [ ] Test purchase flow (sandbox)
- [ ] Test restore purchases
- [ ] Test entitlement persistence across launches

#### Task 7.3: UI Tests
- [ ] Test store view displays products
- [ ] Test upgrade prompts appear at limits
- [ ] Test navigation from prompt to store
- [ ] Test Settings purchase management

#### Task 7.4: Sandbox Testing
- [ ] Create sandbox tester account
- [ ] Test complete purchase flow
- [ ] Test restore on fresh install
- [ ] Test Family Sharing (if enabled)
- [ ] Test interrupted purchase handling

---

## File Structure

```
WrtingShedPro/
├── Store/
│   ├── WSPProduct.swift              # Product enum
│   ├── EntitlementManager.swift      # Entitlement checking
│   └── Views/
│       ├── StoreView.swift           # Main store screen
│       ├── ModuleCardView.swift      # Individual module card
│       └── UpgradePromptView.swift   # Upgrade prompt sheet
├── Products.storekit                  # StoreKit config for testing
```

---

## Dependencies

| Dependency | Purpose | Status |
|------------|---------|--------|
| StoreKitManager | StoreKit 2 wrapper | ✅ Already integrated |
| StoreKit | Apple's IAP framework | ✅ System framework |

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| App Store review rejection | Low | High | Follow guidelines strictly, clear descriptions |
| StoreKitManager API changes | Low | Medium | Pin package version |
| Offline purchase issues | Medium | Medium | Cache entitlements locally |
| CloudKit sync conflicts | Low | Medium | StoreKit 2 handles via App Store account |

---

## Rollback Plan

If issues arise after release:
1. IAP can be disabled via remote config flag (if implemented)
2. All users get full access temporarily
3. Fix issues and release patch
4. Re-enable IAP gating

---

## Success Criteria

- [ ] All 5 products visible in store with correct prices
- [ ] Purchase flow completes without errors
- [ ] Restore purchases works correctly
- [ ] Free tier limits enforced correctly
- [ ] Upgrade prompts appear at appropriate times
- [ ] Purchased modules unlock immediately
- [ ] Bundle unlocks all modules
- [ ] Entitlements persist across app launches
- [ ] Works on both iOS and macOS
