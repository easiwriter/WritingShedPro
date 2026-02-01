# Feature 032: In-App Purchases - Task List

**Status:** In Progress  
**Start Date:** 2026-02-01  
**Target Completion:** ~11 days

---

## Phase 1: Core Infrastructure (Days 1-2) ✅ COMPLETE

### Task 1.1: Product Definitions
- [x] Create `Store/WSPProduct.swift`
- [x] Define `WSPProduct` enum with 5 cases
- [x] Add `allProductIDs` computed property
- [x] Add `projectType` computed property
- [x] Add unit tests

### Task 1.2: Entitlement Manager
- [x] Create `Store/EntitlementManager.swift`
- [x] Inject StoreKitManager dependency
- [x] Implement `isModulePurchased(_:)`
- [x] Implement `isProjectTypeUnlocked(_:)`
- [x] Handle bundle unlocks all logic
- [x] Add unit tests

### Task 1.3: App Integration
- [x] Add EntitlementManager to environment
- [x] Initialize StoreKitManager with product IDs
- [x] Load products on app startup
- [x] Listen for transaction updates

---

## Phase 2: Free Tier Gating (Days 3-4) ✅ COMPLETE

### Task 2.1: Project Count Limits
- [x] Add helper to count projects by type
- [x] Implement `canCreateProject(ofType:existingCount:)`
- [x] Modify project creation to check entitlement
- [x] Show upgrade prompt if limit reached
- [ ] Add unit tests

### Task 2.2: File Count Limits
- [x] Add helper to count files in project
- [x] Implement `canCreateFile(inProject:existingCount:)`
- [x] Modify file creation to check entitlement
- [x] Show upgrade prompt if limit reached
- [ ] Add unit tests

### Task 2.3: Export Gating
- [x] Implement `canExport(project:)`
- [x] Modify export flow to check entitlement
- [ ] Disable/dim export buttons when blocked
- [x] Show upgrade prompt if blocked
- [ ] Add unit tests

### Task 2.4: Print Gating
- [x] Implement `canPrint(project:)`
- [x] Modify print flow to check entitlement
- [ ] Disable/dim print buttons when blocked
- [x] Show upgrade prompt if blocked
- [ ] Add unit tests

---

## Phase 3: Upgrade Prompt UI (Day 5) ✅ COMPLETE

### Task 3.1: Upgrade Prompt View
- [x] Create `Store/UpgradePromptView.swift`
- [x] Accept feature/module parameters
- [x] Display blocked action message
- [x] Show module card with price
- [x] Add "View All Modules" button
- [x] Add "Not Now" dismiss button

### Task 3.2: Prompt Presentation
- [x] Create state for showing prompt
- [x] Add `.sheet` modifier to root views
- [x] Pass context (which limit hit)
- [ ] Handle purchase completion

### Task 3.3: Integration Points
- [x] Wire to project creation limit
- [x] Wire to file creation limit
- [x] Wire to export limit
- [x] Wire to print limit
- [x] Test all triggers

---

## Phase 4: Store UI (Days 6-7) ✅ COMPLETE

### Task 4.1: Store View
- [x] Create `Store/StoreView.swift`
- [x] Fetch products from StoreKitManager
- [x] Show loading state
- [x] Display module cards
- [x] Feature bundle with "Best Value"
- [x] Add Restore Purchases button
- [x] Add Terms/Privacy links

### Task 4.2: Module Card Component
- [x] Create `ModuleCardView` in StoreView.swift
- [x] Display module icon
- [x] Display module name
- [x] Display localized price
- [x] Show "Owned ✓" if purchased
- [x] Buy button with loading state

### Task 4.3: Purchase Flow UI
- [x] Show loading during purchase
- [x] Handle success (refresh entitlements)
- [x] Handle cancellation
- [ ] Handle failure (error alert) - basic handling, no alert yet

### Task 4.4: Bundle Card
- [x] Special styling for bundle
- [x] "Best Value - Save 30%" badge
- [x] List included modules with icons
- [x] Prominent placement at top

---

## Phase 5: Settings Integration (Day 8) ✅ COMPLETE

### Task 5.1: Settings Row
- [x] Add "Manage Purchases" to Settings menu
- [ ] Show owned module count
- [x] Navigate to StoreView

### Task 5.2: Owned Modules Display
- [ ] Show owned with checkmarks
- [ ] Show available with prices
- [ ] Restore Purchases button
- [ ] Handle restore success/failure

---

## Phase 6: App Store Connect Setup (Day 9) ✅ COMPLETE

### Task 6.1: Create Products
- [x] com.writingshedpro.prosewriter
- [x] com.writingshedpro.poetrywriter
- [x] com.writingshedpro.fictionwriter
- [x] com.writingshedpro.dramawriter
- [x] com.writingshedpro.allinbundle

### Task 6.2: Configure Products
- [x] Set reference names
- [x] Set price tiers
- [x] Add localized display names
- [x] Add localized descriptions
- [ ] Add review screenshots (App Store Connect)

### Task 6.3: StoreKit Config File
- [x] Create `Products.storekit`
- [x] Add all 5 products
- [x] Configure for sandbox
- [ ] Verify in simulator

---

## Phase 7: Testing (Days 10-11) 🔄 IN PROGRESS

### Task 7.1: Unit Tests
- [x] Test WSPProduct enum
- [x] Test EntitlementManager
- [x] Test free tier limits
- [x] Test bundle logic
- [ ] Test edge cases

### Task 7.2: Integration Tests
- [ ] Test product loading
- [ ] Test purchase flow
- [ ] Test restore purchases
- [ ] Test entitlement persistence

### Task 7.3: UI Tests
- [ ] Test store displays products
- [ ] Test upgrade prompts appear
- [ ] Test navigation flows
- [ ] Test Settings integration

### Task 7.4: Sandbox Testing
- [ ] Create sandbox account
- [ ] Test complete purchase
- [ ] Test restore on fresh install
- [ ] Test Family Sharing
- [ ] Test interrupted purchases

---

## Final Checklist

- [ ] All products visible with correct prices
- [ ] Purchase flow works end-to-end
- [ ] Restore purchases works
- [ ] Free tier limits enforced
- [ ] Upgrade prompts work
- [ ] Purchased modules unlock immediately
- [ ] Bundle unlocks all modules
- [ ] Entitlements persist across launches
- [ ] Works on iOS
- [ ] Works on macOS
- [ ] Code reviewed
- [ ] Documentation updated
