# Feature Specification: In-App Purchases & Subscriptions

**Feature ID**: 014  
**Created**: 9 November 2025  
**Status**: Planning / Business Critical  
**Priority**: High (Required for monetization)  
**Dependencies**: Core app functionality

---

## Overview

Implement in-app purchases and subscription system using Apple's StoreKit 2 framework to monetize Writing Shed Pro.

---

## Goals

- Offer free tier with limited features
- Provide Pro subscription with full feature access
- Support one-time purchases for specific features
- Handle subscription management (upgrade, cancel, restore)
- Comply with App Store guidelines
- Provide excellent free trial experience
- Support family sharing
- Handle edge cases gracefully (failed payments, etc.)

---

## Monetization Strategy

### Freemium Model

**Free Tier** (Forever free):
- ✅ 1 project
- ✅ Unlimited files per project
- ✅ Basic text editing
- ✅ Text formatting (bold, italic, underline)
- ✅ Word count
- ✅ iCloud sync (limited)
- ✅ Search within project
- ❌ Multiple projects
- ❌ Advanced features (submissions, version history, etc.)
- ❌ Export to PDF/Word
- ❌ Custom themes

**Pro Subscription** (Monthly or Annual):
- ✅ Everything in Free
- ✅ Unlimited projects
- ✅ Full version history
- ✅ Publication/submission tracking
- ✅ Advanced export formats (PDF, DOCX, EPUB)
- ✅ Novel/Poetry/Script specific features
- ✅ Custom themes and fonts
- ✅ OpenAI integration (see Feature 015)
- ✅ Priority support
- ✅ Early access to new features
- ✅ Family Sharing

**Free Trial**:
- 14-day free trial of Pro
- No credit card required initially
- Full access to all Pro features
- Prompt to subscribe at end of trial

### Pricing Options

**Monthly**: $4.99/month
**Annual**: $44.99/year (save 25%)
**Lifetime**: $99.99 (one-time purchase, optional)

**Family Sharing**: Up to 6 family members

---

## Feature Gating

### Free Tier Limitations

#### Project Limit
```swift
class SubscriptionService {
    func canCreateProject() -> Bool {
        if isPro {
            return true
        }
        
        let projectCount = getCurrentProjectCount()
        return projectCount < 1  // Free: 1 project
    }
}
```

**UI When Limit Reached**:
```
┌─────────────────────────────────────┐
│ Project Limit Reached               │
├─────────────────────────────────────┤
│ Free tier includes 1 project.       │
│                                     │
│ Upgrade to Pro for:                 │
│ ✓ Unlimited projects                │
│ ✓ Version history                   │
│ ✓ Publication tracking              │
│ ✓ Advanced exports                  │
│                                     │
│ [Maybe Later]  [Start Free Trial]   │
└─────────────────────────────────────┘
```

#### Feature Paywalls

**When tapping Pro-only feature**:
```
┌─────────────────────────────────────┐
│ 🌟 Pro Feature                      │
├─────────────────────────────────────┤
│ Publication tracking is available   │
│ with Writing Shed Pro.              │
│                                     │
│ Start your free 14-day trial to     │
│ unlock this and all Pro features.   │
│                                     │
│ [Learn More]   [Start Free Trial]   │
└─────────────────────────────────────┘
```

#### Graceful Degradation

**If Pro subscription expires**:
- User keeps all their data
- Excess projects become read-only (can view, not edit)
- Pro features disabled but no data loss
- Can export essential data
- Gentle prompts to resubscribe

**Example**:
```
┌─────────────────────────────────────┐
│ Pro Subscription Expired            │
├─────────────────────────────────────┤
│ Your Pro features have expired.     │
│                                     │
│ Your projects are safe, but you     │
│ can only edit 1 project in the      │
│ free tier.                          │
│                                     │
│ Choose a project to keep active:    │
│ ⦿ My Novel (active)                 │
│ ○ Poetry Collection (read-only)     │
│ ○ Short Stories (read-only)         │
│                                     │
│ [Resubscribe to Pro]                │
└─────────────────────────────────────┘
```

---

## StoreKit 2 Implementation

### Product IDs

```swift
enum ProductID: String, CaseIterable {
    case proMonthly = "com.writingshedpro.monthly"
    case proAnnual = "com.writingshedpro.annual"
    case proLifetime = "com.writingshedpro.lifetime"
    
    // Optional: Individual feature purchases
    case advancedExport = "com.writingshedpro.export"
    case poetryTools = "com.writingshedpro.poetry"
}
```

### Store Manager

```swift
@Observable
class StoreManager {
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    
    var isPro: Bool {
        purchasedProductIDs.contains { id in
            id == ProductID.proMonthly.rawValue ||
            id == ProductID.proAnnual.rawValue ||
            id == ProductID.proLifetime.rawValue
        }
    }
    
    // Load products from App Store
    func loadProducts() async throws {
        let productIDs = ProductID.allCases.map { $0.rawValue }
        products = try await Product.products(for: productIDs)
    }
    
    // Purchase product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
            return transaction
            
        case .userCancelled:
            return nil
            
        case .pending:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    // Restore purchases
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedProducts()
    }
    
    // Check transaction verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    // Listen for transaction updates
    func observeTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                let transaction = try self.checkVerified(result)
                await self.updatePurchasedProducts()
                await transaction.finish()
            }
        }
    }
    
    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = purchased
    }
}

enum StoreError: Error {
    case verificationFailed
    case purchaseFailed
}
```

---

## Subscription UI

### Paywall Screen

```
┌─────────────────────────────────────┐
│ ✨ Upgrade to Pro                   │
├─────────────────────────────────────┤
│ Start your 14-day free trial        │
│                                     │
│ ✓ Unlimited projects                │
│ ✓ Full version history              │
│ ✓ Publication tracking              │
│ ✓ Advanced export (PDF, DOCX)       │
│ ✓ Custom themes & fonts             │
│ ✓ AI writing assistance             │
│ ✓ Family Sharing                    │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🏆 Annual                       │ │
│ │ $44.99/year                     │ │
│ │ Save 25%                        │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Monthly                         │ │
│ │ $4.99/month                     │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Lifetime                        │ │
│ │ $99.99 once                     │ │
│ │ Never pay again                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│ Cancel anytime • Restore purchases  │
│                                     │
│ [Terms of Service] [Privacy Policy] │
└─────────────────────────────────────┘
```

### Settings Integration

```
┌─────────────────────────────────────┐
│ ← Settings                          │
├─────────────────────────────────────┤
│ Subscription                        │
│                                     │
│ ✅ Writing Shed Pro                 │
│    Annual subscription              │
│    Renews: Dec 9, 2025              │
│                                     │
│    [Manage Subscription]            │
│    [Cancel Subscription]            │
│    [Restore Purchases]              │
│                                     │
│ ─────────────────────────────────   │
│                                     │
│ Free Trial Available                │
│ 14 days of Pro features, free!      │
│ [Start Free Trial]                  │
│                                     │
│ ─────────────────────────────────   │
│                                     │
│ Not subscribed                      │
│ Unlock unlimited projects and more  │
│ [See Pro Features]                  │
└─────────────────────────────────────┘
```

---

## Free Trial Flow

### Trial Start

```swift
func startFreeTrial() async throws {
    // StoreKit 2 handles trial automatically
    // Just purchase the subscription product
    guard let annual = products.first(where: { 
        $0.id == ProductID.proAnnual.rawValue 
    }) else {
        throw StoreError.productNotFound
    }
    
    _ = try await purchase(annual)
    // If eligible, trial starts automatically
}
```

### Trial Status

```swift
func getTrialStatus() async -> TrialStatus {
    // Check if user has active subscription
    if isPro {
        // Check if in trial period
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            if transaction.productID == ProductID.proAnnual.rawValue ||
               transaction.productID == ProductID.proMonthly.rawValue {
                
                // Check if original purchase was trial
                if let introOffer = transaction.offerType,
                   case .introductory = introOffer {
                    return .inTrial
                }
                return .subscribed
            }
        }
    }
    
    // Check if user is eligible for trial
    let eligibility = await product.subscription?.isEligibleForIntroOffer
    if eligibility == true {
        return .eligible
    }
    
    return .notEligible
}

enum TrialStatus {
    case eligible
    case inTrial
    case subscribed
    case notEligible
}
```

### Trial Ending Reminder

```
┌─────────────────────────────────────┐
│ Trial Ending Soon                   │
├─────────────────────────────────────┤
│ Your 14-day trial ends in 3 days.   │
│                                     │
│ Continue enjoying Pro features:     │
│ • Unlimited projects                │
│ • Version history                   │
│ • Publication tracking              │
│ • And more...                       │
│                                     │
│ Annual: $44.99/year (save 25%)      │
│ Monthly: $4.99/month                │
│                                     │
│ [Cancel Trial]    [Subscribe]       │
└─────────────────────────────────────┘
```

---

## Family Sharing

**Enable in App Store Connect**:
- Mark subscriptions as family sharable
- Up to 6 family members included

**User Experience**:
- Primary subscriber purchases Pro
- Family members get Pro automatically
- No separate purchase needed
- Managed through Apple ID Family Sharing

**Implementation**:
```swift
// StoreKit 2 handles this automatically
// Just verify transaction as normal
// Family members will have valid entitlements
```

---

## Purchase Restoration

### When to Restore

- After reinstalling app
- On new device
- If subscription not showing
- User taps "Restore Purchases"

### Implementation

```swift
func restorePurchases() async throws {
    // Sync with App Store
    try await AppStore.sync()
    
    // Update purchased products
    await updatePurchasedProducts()
    
    // Show confirmation
    if isPro {
        showAlert("Purchases restored successfully!")
    } else {
        showAlert("No purchases found to restore.")
    }
}
```

---

## Edge Cases & Error Handling

### Subscription Expired

**Behavior**:
- User notified (gentle, not alarming)
- Pro features disabled
- Data remains accessible
- Can resubscribe anytime

### Failed Payment

**Handling**:
- Apple shows billing retry alert
- User has grace period (varies by region)
- App shows payment issue banner
- Link to update payment method

### Refund Issued

**Handling**:
- StoreKit notifies app of revocation
- Remove Pro entitlement immediately
- Don't delete user's data
- User can repurchase

### Family Member Removed

**Handling**:
- Subscription access revoked
- User offered to purchase individually
- Data preserved

---

## Analytics & Metrics

### Track Key Events

```swift
enum SubscriptionEvent {
    case paywallShown
    case trialStarted
    case trialConverted
    case trialExpired
    case monthlyPurchased
    case annualPurchased
    case lifetimePurchased
    case subscriptionCancelled
    case subscriptionRestored
}

func logEvent(_ event: SubscriptionEvent) {
    // Log to analytics service
    // Track conversion funnels
    // Measure retention
}
```

### Metrics to Monitor

- Trial start rate
- Trial-to-paid conversion rate
- Monthly vs. annual split
- Lifetime purchase rate
- Churn rate
- Average revenue per user (ARPU)
- Lifetime value (LTV)

---

## Legal & Compliance

### Required Disclosures

**Subscription Auto-Renewal Terms**:
```
• Payment will be charged to your Apple ID at confirmation of purchase
• Subscription automatically renews unless canceled at least 24 hours before the end of the current period
• Your account will be charged for renewal within 24 hours prior to the end of the current period
• You can manage and cancel your subscriptions in your account settings on the App Store
• Any unused portion of a free trial period will be forfeited when you purchase a subscription
```

**Links Required**:
- Terms of Service
- Privacy Policy
- Subscription terms (auto-renewal disclosure)

### Privacy

- No subscription data collected outside Apple's system
- StoreKit handles all payment processing
- User data protected per privacy policy
- Subscription status synced via CloudKit (optional)

---

## Testing

### StoreKit Testing in Xcode

**Setup**:
1. Create StoreKit Configuration file
2. Add products with IDs matching production
3. Test subscriptions, trials, purchases
4. Test failure scenarios

**Test Scenarios**:
- Purchase monthly subscription
- Purchase annual subscription
- Start free trial
- Cancel trial before conversion
- Let trial convert to paid
- Restore purchases
- Family sharing
- Expired subscription
- Failed payment
- Refund

### Sandbox Testing

**Test Accounts**:
- Create sandbox accounts in App Store Connect
- Test on real device with sandbox account
- Verify receipts and entitlements

### Production Testing (Beta)

- TestFlight beta with real purchases
- Monitor crash logs and errors
- Gather user feedback on pricing
- A/B test paywall messaging

---

## Implementation Phases

### Phase 1: Core IAP
- StoreKit 2 integration
- Product loading
- Purchase flow
- Restore purchases
- Basic paywall

### Phase 2: Subscription Management
- Trial tracking
- Subscription status UI
- Cancellation handling
- Family sharing

### Phase 3: Feature Gating
- Free tier limits
- Pro feature paywalls
- Graceful degradation
- Project limit enforcement

### Phase 4: Optimization
- Paywall A/B testing
- Analytics integration
- Conversion optimization
- Upsell messaging

---

## Open Questions

1. **Pricing**: Are $4.99/month and $44.99/year optimal?
2. **Trial length**: 14 days vs. 7 days vs. 30 days?
3. **Free tier**: Is 1 project enough or too restrictive?
4. **Lifetime option**: Include or skip?
5. **Regional pricing**: Auto-adjust for purchasing power parity?
6. **Student discount**: Offer educational pricing?
7. **Bundle**: Offer with other apps?

---

## Dependencies

- App Store Connect setup
- Tax forms submitted
- Paid Agreements signed
- Products configured in App Store Connect
- StoreKit 2 framework

---

## Success Metrics

- **Trial conversion**: > 15% of trials convert to paid
- **Subscriber retention**: > 80% renewal rate after 6 months
- **Revenue**: Meet monthly revenue targets
- **Support tickets**: < 5% related to billing issues
- **User satisfaction**: 4.5+ App Store rating despite IAP

---

## Related Resources

- StoreKit 2 documentation: https://developer.apple.com/storekit/
- App Store Review Guidelines: Section 3 (Business)
- Human Interface Guidelines: In-App Purchase
- WWDC sessions on StoreKit 2

---

**Status**: 📋 Specification Draft - Business Critical  
**Next Steps**: Finalize pricing, configure App Store Connect, implement StoreKit integration  
**Estimated Effort**: Medium (3-4 weeks)  
**Risk**: Medium (subscription systems complex, testing crucial)
