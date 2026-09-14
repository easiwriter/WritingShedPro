# Feature 044: New IAP Structure

**Status**: Planning
**Priority**: High
**Estimated Effort**: Medium
**Dependencies**: Feature 032 - In-App Purchases
**Created**: 2026-09-14
**Implementation**: TBD

## Overview

The current IAP structure and purchasing model will be replaced for new users. For compatibility, existing users must not see any change in their available products, existing purchases, free-tier limits, or Manuscript Analyst access.

The new model consists of two non-consumable IAPs:

1. Ten-Day Free Trial (`com.writingshedpro.trial10day`, free)
2. Writing Shed Pro Full Access (`com.writingshedpro.fullaccess`, £24.99 UK base price)

When a new user first launches the app, they are presented with a mandatory access paywall offering Start 10-Day Free Trial, Buy Full Access, and Restore Purchases. The trial starts from the verified StoreKit transaction date and lasts exactly 240 hours. During the trial, the user has unrestricted access to all core project types and features. The legacy free-tier restrictions, such as one project per type, one file per project, and blocked printing or export, do not apply to users of the new model during an active trial.

After the trial expires, the user can continue to navigate, search, and read existing work, but all user-initiated content changes, import, printing, export, and new Manuscript Analyst requests are blocked until Full Access is purchased. The Full Access purchase permanently unlocks all core project types and features. Manuscript Analyst remains a separate subscription and, for new-model users, also requires Full Access.

Do not let individual gating controls determine whether somebody is a new or existing user. All classification, entitlement, trial, compatibility, and capability decisions must be centralized in the StoreKit/entitlement manager.

## Goals

1. Replace the legacy module-based purchase model with a simpler trial and lifetime Full Access model for new users.
2. Preserve the current purchase model and behavior for every user whose original app version predates version 19.0.
3. Give new users unrestricted core access for an exact ten-day evaluation period.
4. Protect user data after expiry by preserving navigation and reading while blocking all user-initiated mutations.
5. Make trial status and remaining time visible without distracting from the writing experience.
6. Keep all purchase-model and capability decisions inside the entitlement layer.
7. Support restore, Family Sharing, reinstall, additional devices, offline use, refunds, and revoked transactions predictably.

## Requirements

### 1. Products

- `com.writingshedpro.trial10day` is a free non-consumable IAP that activates one ten-day trial.
- `com.writingshedpro.fullaccess` is a paid non-consumable IAP that permanently unlocks all core Writing Shed Pro features.
- The displayed Full Access price must come from StoreKit and use the storefront's localized price. The specification's £24.99 price is the UK base price, not hard-coded UI text.
- Family Sharing must be enabled and supported for the trial, Full Access, and all legacy module products.
- `com.writingshedpro.manuscriptanalyst` remains a separate subscription and is not included with Full Access.
- Legacy module and bundle product identifiers must remain registered so existing and family-shared purchases can be restored and verified.

### 2. User Classification and Compatibility

- Version 19.0 is the purchase-model cutover release.
- A verified `AppTransaction.originalAppVersion` earlier than 19.0 identifies a legacy user.
- A verified `AppTransaction.originalAppVersion` of 19.0 or later identifies a new-model user.
- Version comparison must be numeric by components, not lexicographic string comparison.
- Classification must survive reinstall and use on another device; local installation date or local UserDefaults alone must not determine the model.
- Until StoreKit verifies the app transaction, the app must not permanently classify or persist the user as new-model.
- Legacy users retain the existing Store screen, individual module entitlements, All-in Bundle behavior, free-tier limits, upgrade prompts, and Manuscript Analyst rules.
- A legacy user's individual module purchase unlocks exactly the same module as before. It must not silently grant Full Access.
- A family-shared legacy transaction must provide the same entitlement as a directly purchased legacy transaction.
- New-model users must never be shown legacy individual modules or the legacy All-in Bundle as purchase options.
- Individual views and commands must not inspect original app version, product history, or trial dates to determine access.

### 3. First-Launch Access Paywall

- A new-model user with neither an activated trial nor Full Access must remain at a mandatory access paywall.
- The paywall must offer:
  - Start 10-Day Free Trial
  - Buy Full Access
  - Restore Purchases
- The paywall must clearly state that the trial lasts ten days, does not renew, and does not result in an automatic charge.
- Dismissing the initial paywall without activating the trial, buying Full Access, or restoring a qualifying purchase must not grant app access.
- After trial activation or Full Access purchase, a genuinely new user proceeds into the existing onboarding flow.
- Restoring a legacy account with existing synced projects may bypass onboarding according to the existing onboarding eligibility rules.
- The trial product must not be offered again after a verified trial transaction has been recorded, including after expiry.

### 4. Trial Timing

- The trial lasts exactly 240 hours from the authoritative verified StoreKit transaction date.
- The trial is shared across reinstall, the user's devices, and Family Sharing wherever StoreKit supplies the verified transaction.
- Trial expiry is calculated as `trialStart + 240 hours`.
- More than 24 hours remaining is displayed as a whole-day countdown, for example `Trial: 7 days remaining`.
- During the final 24 hours, display `Less than 1 day remaining`.
- At or after expiry, display `Trial expired`.
- The countdown and access state must refresh when the app launches, becomes active, receives a StoreKit transaction update, or crosses the expiry boundary while running.
- The app must retain a locally cached verified trial start and expiry for offline evaluation.
- The app must persist the latest trusted observed time and must not allow a backward device-clock change to extend the trial.
- A backward clock change alone must not immediately lock a legitimate offline user. Continue from the latest trusted time and request StoreKit verification when connectivity returns.

### 5. Active Trial Capabilities

- An active trial provides unrestricted access to all core project types and core features.
- Legacy project-count and file-count limits do not apply.
- Creating, editing, importing, deleting, moving, renaming, reordering, printing, and exporting are allowed.
- Full Access prompts may be displayed as trial status or expiry warnings, but must not interrupt ordinary actions before expiry.
- Manuscript Analyst is unavailable during the trial unless the user also owns Full Access and has an active Analyst subscription.

### 6. Expired Trial and Read-Only Mode

- On first detection of expiry, present the Full Access paywall.
- The expiry paywall must be dismissible with Not Now so the user can continue in read-only mode.
- Read-only mode permits navigation, opening and reading content, search, viewing existing Manuscript Analyst reports, Help, support, Settings, Store access, purchase, and purchase restoration.
- Read-only mode blocks every user-initiated content mutation, including:
  - creating or importing projects, folders, files, versions, collections, submissions, publications, styles, or other content;
  - editing document text, formatting, images, footnotes, comments, metadata, notes, statuses, project details, or manuscript/page settings;
  - renaming, deleting, restoring, duplicating, moving, assigning, or reordering content;
  - undo or redo operations that mutate persisted content;
  - printing and all export/share/save-as paths that expose document or project content;
  - starting a new Manuscript Analyst analysis.
- Read-only enforcement applies to user commands and editing controls, not to background persistence globally.
- Sync, remote merges, migrations, entitlement refresh, and other required system maintenance must continue in read-only mode.
- A Full Access purchase or restored Full Access entitlement must remove read-only restrictions immediately after verification.

### 7. Trial Status and Warnings

- The main Projects screen must show a compact, tappable trial indicator near Settings.
- Tapping the indicator opens the Full Access purchase screen.
- Settings must show detailed trial status, the exact expiry date, and an Unlock Full Access action.
- Show prominent warnings when three days remain, when one day remains, and on first detection of expiry.
- Each warning must be shown at most once for its threshold per trial, while the persistent indicator remains visible.
- After expiry, retain a visible `Trial Expired - Unlock Full Access` indicator.
- Do not place a persistent countdown in every editor screen.
- Legacy users and Full Access owners must not see trial countdown or expiry UI.

### 8. Store Presentation

- Store presentation must be selected by the entitlement manager's user model and access state.
- Legacy users see the four legacy modules, All-in Bundle, Restore Purchases, and Manuscript Analyst under the existing rules.
- New-model users see Full Access, Restore Purchases, and appropriate Manuscript Analyst information.
- During an active trial, Full Access remains available for purchase.
- After expiry, Full Access is the primary Store action.
- The trial product is shown only on the mandatory activation paywall and only before activation.
- New-model users must not see legacy products.
- For new-model users, Manuscript Analyst purchase and use require Full Access. The Store may explain Analyst availability before Full Access, but must not permit purchase or use until Full Access is verified.
- For legacy users, Manuscript Analyst retains its existing entitlement behavior and does not gain a new Full Access prerequisite.

### 9. Offline Behavior

- Previously verified Full Access remains available offline using cached verified entitlement state.
- A previously activated trial continues offline according to its cached authoritative start, expiry, and latest trusted time.
- A new user who has never activated the trial must remain at the activation paywall until StoreKit is available to complete and verify activation.
- An expired trial remains read-only offline.
- Offline state must never convert an existing user to the new model or erase a verified entitlement.
- When connectivity returns, refresh StoreKit entitlements and reconcile any changed state.

### 10. Restore, Refund, Revocation, and Family Sharing

- Restore Purchases must refresh the app transaction, all current entitlements, trial state, Full Access, legacy products, Family Sharing transactions, and the Analyst subscription.
- A revoked or refunded Full Access transaction falls back to an active trial when a valid unexpired trial exists; otherwise it enters read-only mode.
- A revoked trial transaction returns a new-model user without Full Access to the mandatory activation paywall.
- A revoked legacy module removes only that module entitlement and restores its existing legacy free-tier behavior.
- Removal from Family Sharing follows the same fallback rules as revocation.
- Revoked, refunded, expired, or unverified transactions must not be treated as active entitlements.

### 11. Manuscript Analyst

- Manuscript Analyst remains a separately priced subscription.
- For new-model users, starting an analysis requires both Full Access and an active Analyst subscription.
- Full Access alone does not grant Analyst usage.
- An active trial does not satisfy the Full Access prerequisite for Manuscript Analyst.
- After trial expiry, new analyses are blocked until Full Access is purchased, even if the Analyst subscription remains active.
- Existing analysis reports remain readable in expired-trial read-only mode.
- Legacy users retain the Analyst access rules that existed before version 19.0.

### 12. Localization and Accessibility

- All paywall, countdown, warning, read-only, restoration, error, and purchase text must be localized.
- Product prices and currencies must always use StoreKit display values.
- Paywalls and trial indicators must support VoiceOver, Dynamic Type, keyboard navigation where applicable, and clear focus order.
- Disabled mutation controls must provide an accessible explanation and a route to Full Access where appropriate.

## Technical Notes

### 1. Central Entitlement State

Extend `EntitlementManager` so it owns a single authoritative access state. A suitable shape is:

```swift
enum PurchaseModel {
    case legacy
    case trialAndFullAccess
}

enum CoreAccessState {
    case loading
    case activationRequired
    case trialActive(expiresAt: Date)
    case trialExpired
    case fullAccess
    case legacy
}
```

The exact names may follow existing code conventions, but consumers must receive capabilities or a resolved state rather than reproducing classification logic.

### 2. Capability API

Centralize user-action decisions behind entitlement APIs such as:

- `canCreateContent`
- `canModifyContent`
- `canDeleteContent`
- `canImport`
- `canExport`
- `canPrint`
- `canUseManuscriptAnalyst`

Legacy overloads that accept project type and content count may remain internally, but callers must not decide which purchase model applies.

### 3. StoreKit Verification

- Add the two new identifiers to the registered StoreKit product set without removing legacy identifiers.
- Use verified `AppTransaction.shared` data for the original app version classification.
- Use verified current entitlements and transaction updates for Full Access, trial, legacy purchases, Family Sharing, revocation, and refunds.
- Anchor trial timing to the earliest authoritative verified transaction date for the trial product.
- Store only verified transaction-derived values in the durable entitlement cache.
- Treat cached values as offline continuity data, not as a replacement for StoreKit verification when StoreKit is available.

### 4. Trusted Time

- Persist the latest trusted wall-clock value observed while entitlement data is verified online.
- Trial evaluation uses the later of the current device time and latest trusted time.
- Trusted time must move forward only.
- Schedule an in-process expiry task while the app remains active, but always recalculate on activation rather than trusting a timer alone.

### 5. Read-Only Enforcement

- Introduce shared entitlement-aware view modifiers, command guards, or environment capabilities so mutation controls are consistently disabled or intercepted.
- Enforcement must cover keyboard commands, context menus, swipe actions, drag-and-drop, toolbar actions, editor callbacks, import handlers, print paths, export paths, and programmatic user workflows.
- Do not block `ModelContext.save()` globally; synchronization and system maintenance must continue.
- Flush pending editor changes before transitioning from active trial to read-only at expiry so text entered before expiry is not lost.

### 6. Launch Ordering

- Resolve the purchase model and core access state before deciding whether to present the activation paywall or onboarding.
- Do not race an empty local project store, Cloud/Ensembles import, onboarding eligibility, and purchase restoration.
- A loading state should prevent mutation without falsely presenting expiry or activation failure.

### 7. App Store Review Assets

- Provide App Store Connect review screenshots showing the trial activation paywall and Full Access paywall.
- Review notes should explain that the free non-consumable starts a non-renewing 240-hour app trial and that no automatic charge occurs.
- Include working review paths for Start Trial, Buy Full Access, and Restore Purchases.

## Validation

### 1. Classification Tests

- Original app versions before 19.0 resolve to the legacy model.
- Original app version 19.0 and later resolve to the new model.
- Numeric version comparison handles values such as 18.10 and 19.0 correctly.
- Missing, unverified, or temporarily unavailable app transactions do not permanently misclassify a legacy user.
- Reinstall and second-device restoration preserve classification.

### 2. Trial Tests

- A verified trial purchase starts exactly one 240-hour trial.
- Trial status survives relaunch, reinstall, another device, and Family Sharing restoration.
- The trial cannot be activated a second time after expiry.
- Access remains active immediately before expiry and becomes read-only at expiry.
- Final-day and whole-day countdown text changes at the correct boundaries.
- Three-day, one-day, and expiry warnings each appear once.
- Clock rollback does not extend the trial.
- Offline trial evaluation uses cached verified timing and trusted time.

### 3. Capability Tests

- Active trial and Full Access permit every core mutation, print, and export path.
- Expired-trial mode permits reading, navigation, search, support, Settings, Store, and existing report viewing.
- Expired-trial mode blocks each mutation category listed in Requirement 6, including keyboard, menu, context-menu, drag-and-drop, and programmatic user paths.
- Sync imports, remote merges, migrations, and entitlement persistence still work in read-only mode.
- Pending editor changes entered before expiry are safely flushed when expiry occurs.

### 4. Compatibility Tests

- Legacy users retain existing module-specific unlocks and free-tier limits.
- Legacy All-in Bundle owners retain full core access.
- Legacy Store presentation remains unchanged.
- New-model users never see legacy products.
- Family-shared legacy purchases grant the same module entitlements as direct purchases.
- Existing legacy Analyst subscribers retain current behavior.

### 5. Purchase Lifecycle Tests

- Full Access purchase immediately unlocks core capabilities.
- Restore Purchases reconstructs classification, trial state, Full Access, legacy modules, Family Sharing, and Analyst state.
- Full Access refund or revocation falls back to active trial or read-only as appropriate.
- Trial revocation returns an otherwise unentitled new-model user to activation-required state.
- Family Sharing removal follows the same fallback behavior.
- Offline cached Full Access remains usable and reconciles when connectivity returns.

### 6. Manuscript Analyst Tests

- New-model active-trial users with an Analyst subscription cannot start analyses without Full Access.
- New-model Full Access users with an Analyst subscription can start analyses.
- New-model Full Access users without an Analyst subscription cannot start analyses.
- New-model expired-trial users cannot start analyses even with an active Analyst subscription.
- Existing analysis reports remain readable after trial expiry.
- Legacy Analyst behavior remains unchanged.

### 7. UI, Localization, and Accessibility Tests

- Initial paywall contains Trial, Full Access, and Restore actions and cannot be bypassed without entitlement.
- Expiry paywall is dismissible into read-only mode.
- Trial indicator and Settings detail display the correct state and localized expiry information.
- Store content changes correctly for legacy, active-trial, expired-trial, and Full Access states.
- StoreKit localized prices are displayed instead of hard-coded currency text.
- All new localization keys resolve to user-facing text.
- Paywall, warnings, trial indicators, and disabled controls pass VoiceOver, Dynamic Type, keyboard, and focus-order checks on iPhone, iPad, and Mac Catalyst.
