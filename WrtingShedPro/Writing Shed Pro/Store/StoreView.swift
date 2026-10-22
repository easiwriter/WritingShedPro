//
//  StoreView.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import SwiftUI
import StoreKit
import StoreKitManager

@MainActor
enum OfferCodeRedemptionPresenter {
    static func present(onEntitlementsRefreshed: (() -> Void)? = nil) {
        #if !targetEnvironment(macCatalyst)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        Task {
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
                try? await Task.sleep(for: .seconds(2))
                await EntitlementManager.shared.refreshEntitlements()
                onEntitlementsRefreshed?()
            } catch {
                print("Failed to present offer code sheet: \(error)")
            }
        }
        #else
        if let url = URL(string: "https://apps.apple.com/redeem") {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

/// Main store view for Full Access, eligible trials, and Manuscript Analyst.
@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @StateObject private var storeManager = StoreKitPurchaseManager.shared

    var requiresAccessSelection = false
    
    /// Optional: highlight a specific product (from upgrade prompt)
    var highlightedProduct: WSPProduct?

    /// Optional: automatically trigger the StoreKit payment sheet for this product once loaded
    var autoPurchaseProduct: WSPProduct? = nil
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var purchaseError: String?
    @State private var showRestoreSuccess = false
    @State private var purchaseInProgress: String?
    @State private var loadedProducts: [Product] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header (compact)
                    headerSection
                    
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                        restoreSection
                    } else {
                        purchaseContent
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(
                NSLocalizedString("iap.new.title", comment: "New IAP store title")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !requiresAccessSelection {
                        Button("Not Now") {
                            dismiss()
                        }
                    }
                }
            }
            .task {
                await loadProducts()
            }
            .task {
                // Listen for transaction updates (required by StoreKit to catch completed purchases)
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        await transaction.finish()
                        EntitlementManager.shared.recordVerifiedPurchase(transaction)
                        await SalesReporter.recordSale(for: transaction)
                        await EntitlementManager.shared.refreshEntitlements()
                        await requestFullAccessReviewIfNeeded(for: transaction)
                    }
                }
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your purchases have been restored successfully.")
            }
            .alert(
                NSLocalizedString("iap.purchase.unavailable", comment: "Purchase unavailable alert title"),
                isPresented: Binding(
                    get: { purchaseError != nil },
                    set: { if !$0 { purchaseError = nil } }
                )
            ) {
                Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
            } message: {
                Text(purchaseError ?? "")
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerSection: some View {
        VStack(spacing: 6) {
            Image(systemName: "pencil.and.outline")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text(
                NSLocalizedString("iap.new.heading", comment: "New IAP heading")
            )
                .font(.headline)
                .fontWeight(.bold)
            
            Text(
                EntitlementManager.shared.purchaseModel == .trialAndFullAccess
                    ? NSLocalizedString("iap.new.subheading", comment: "New IAP subheading")
                    : NSLocalizedString("iap.fullAccess.legacySubheading", comment: "Full Access upgrade for legacy users")
            )
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }

    private var purchaseContent: some View {
        VStack(spacing: 16) {
            if EntitlementManager.shared.purchaseModel == .trialAndFullAccess,
               let trialProduct = product(for: .tenDayTrial) {
                ModuleCardView(
                    wspProduct: .tenDayTrial,
                    storeProduct: trialProduct,
                    isPurchased: EntitlementManager.shared.hasActivatedTrial
                        || EntitlementManager.shared.hasFullAccess,
                    isHighlighted: EntitlementManager.shared.requiresTrialActivation,
                    isLoading: purchaseInProgress == trialProduct.id,
                    onPurchase: { await purchase(trialProduct) },
                    onRedeemCode: { presentOfferCodeRedemption() }
                )

                Text(NSLocalizedString("iap.trial.noRenewal", comment: "Trial does not renew or charge"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let fullAccessProduct = product(for: .fullAccess) {
                ModuleCardView(
                    wspProduct: .fullAccess,
                    storeProduct: fullAccessProduct,
                    isPurchased: EntitlementManager.shared.hasFullAccess,
                    isHighlighted: !EntitlementManager.shared.requiresTrialActivation,
                    isLoading: purchaseInProgress == fullAccessProduct.id,
                    onPurchase: { await purchase(fullAccessProduct) },
                    onRedeemCode: { presentOfferCodeRedemption() }
                )
            }

            if EntitlementManager.shared.canPurchaseManuscriptAnalyst {
                analystSubscriptionSection
            } else {
                Label(
                    NSLocalizedString("iap.analyst.requiresFullAccess", comment: "Analyst requires Full Access"),
                    systemImage: "lock.fill"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            restoreSection
            legalSection
        }
    }
    
    @ViewBuilder
    private var analystSubscriptionSection: some View {
        if let analystProduct = product(for: .manuscriptAnalystSubscription) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Manuscript Analyst")
                    .font(.headline)

                ModuleCardView(
                    wspProduct: .manuscriptAnalystSubscription,
                    storeProduct: analystProduct,
                    isPurchased: EntitlementManager.shared.isManuscriptAnalystSubscriptionActive(),
                    isHighlighted: highlightedProduct == .manuscriptAnalystSubscription,
                    isLoading: purchaseInProgress == analystProduct.id,
                    onPurchase: { await purchase(analystProduct) },
                    onRedeemCode: { presentOfferCodeRedemption() }
                )
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading products...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Unable to Load Products")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await loadProducts() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    private var restoreSection: some View {
        VStack(spacing: 12) {
            Button {
                Task { await restorePurchases() }
            } label: {
                Label("Restore Purchases", systemImage: "arrow.clockwise")
                    .font(.subheadline)
            }
            
            Text("Already purchased? Restore your previous purchases here.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
                .padding(.vertical, 8)
            
            // Offer code redemption
            Button {
                presentOfferCodeRedemption()
            } label: {
                Label("Redeem Offer Code", systemImage: "ticket")
                    .font(.subheadline)
            }
            
            Text("Have an offer code? Redeem it here for free or discounted access.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    /// Present the App Store offer code redemption sheet
    private func presentOfferCodeRedemption() {
        OfferCodeRedemptionPresenter.present()
    }
    
    private var legalSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("•")
                    .foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://appworks.pro/wsp-privacy-policy/")!)
            }
            .font(.caption)
        }
        .padding(.top, 20)
        .padding(.bottom, 40)
    }
    
    // MARK: - Helper Methods
    
    private func product(for wspProduct: WSPProduct) -> Product? {
        loadedProducts.first { $0.id == wspProduct.rawValue }
    }

    private func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load products with our product IDs
            let allIDs = WSPProduct.productsForSale(
                purchaseModel: EntitlementManager.shared.purchaseModel
            ).map(\.rawValue)
            let products = try await Product.products(for: allIDs)
            
            await MainActor.run {
                loadedProducts = products
                isLoading = false
                
                if !products.contains(where: { $0.id == WSPProduct.fullAccess.rawValue }) {
                    errorMessage = NSLocalizedString("iap.fullAccess.unavailable", comment: "Full Access product unavailable")
                }
                
                #if DEBUG
                print("📦 Loaded \(products.count) products: \(products.map { $0.id })")
                #endif
            }

            // Retired module requests use the current Full Access product.
            if let target = autoPurchaseProduct?.currentPurchaseProduct,
               let storeProduct = products.first(where: { $0.id == target.rawValue }) {
                await purchase(storeProduct)
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                
                #if DEBUG
                print("❌ Failed to load products: \(error)")
                #endif
            }
        }
    }
    
    private func purchase(_ product: Product) async {
        if product.id == WSPProduct.manuscriptAnalystSubscription.rawValue,
           !EntitlementManager.shared.canPurchaseManuscriptAnalyst {
            purchaseError = NSLocalizedString(
                "iap.analyst.requiresFullAccess",
                comment: "Analyst requires Full Access"
            )
            return
        }

        #if DEBUG
        if product.id == WSPProduct.tenDayTrial.rawValue,
           EntitlementManager.shared.isPaywallCaptureModeEnabled {
            await EntitlementManager.shared.setPaywallCaptureModeEnabled(false)
            if !EntitlementManager.shared.requiresTrialActivation {
                dismiss()
                return
            }
        }
        #endif

        purchaseInProgress = product.id
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    // Record immediately so the entitlement is available even if
                    // Transaction.currentEntitlements hasn't updated yet (iOS timing issue).
                    EntitlementManager.shared.recordVerifiedPurchase(transaction)
                    await SalesReporter.recordSale(for: transaction)
                    await EntitlementManager.shared.refreshEntitlements()
                    // Dismiss the store after successful purchase
                    await MainActor.run {
                        dismiss()
                    }
                    await requestFullAccessReviewIfNeeded(for: transaction)
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            if product.id == WSPProduct.tenDayTrial.rawValue {
                try? await AppStore.sync()
                await EntitlementManager.shared.refreshEntitlements()
                if !EntitlementManager.shared.requiresTrialActivation {
                    dismiss()
                    purchaseInProgress = nil
                    return
                }
            }

            purchaseError = error.localizedDescription
            #if DEBUG
            print("❌ Purchase failed: \(error.localizedDescription)")
            #endif
        }
        
        purchaseInProgress = nil
    }

    private func requestFullAccessReviewIfNeeded(for transaction: StoreKit.Transaction) async {
        guard transaction.productID == WSPProduct.fullAccess.rawValue,
              ReviewManager.shared.shouldRequestReviewAfterFullAccessPurchase(
                transactionID: String(transaction.id),
                purchaseDate: transaction.originalPurchaseDate
              ) else { return }

        ReviewManager.shared.recordReviewRequest(reason: .fullAccessPurchase)
                dismiss()
        try? await Task.sleep(nanoseconds: 750_000_000)
        requestReview()
    }
    
    private func restorePurchases() async {
        do {
            try await AppStore.sync()
            await EntitlementManager.shared.refreshEntitlements(refreshPurchaseModel: true)
            showRestoreSuccess = true
        } catch {
            #if DEBUG
            print("❌ Restore failed: \(error.localizedDescription)")
            #endif
        }
    }
}

// MARK: - Module Card View

@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
struct ModuleCardView: View {
    let wspProduct: WSPProduct
    let storeProduct: Product
    let isPurchased: Bool
    let isHighlighted: Bool
    let isLoading: Bool
    let onPurchase: () async -> Void
    let onRedeemCode: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: wspProduct.iconName)
                    .font(.title)
                    .foregroundColor(wspProduct.themeColor)
                    .frame(width: 50, height: 50)
                    .background(wspProduct.themeColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(wspProduct.displayName)
                        .font(.headline)
                    Text(wspProduct.shortDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Price / Status
                if isPurchased {
                    Label(
                        wspProduct == .tenDayTrial
                            ? NSLocalizedString("iap.trial.activated", comment: "Trial activation status")
                            : "Owned",
                        systemImage: "checkmark.circle.fill"
                    )
                        .font(.subheadline)
                        .foregroundColor(.green)
                } else if isLoading {
                    ProgressView()
                } else {
                    Button {
                        Task { await onPurchase() }
                    } label: {
                        Text(storeProduct.displayPrice)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(wspProduct.themeColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
            
            // Offer code link (only show if not purchased)
            if !isPurchased {
                Divider()
                Button {
                    onRedeemCode()
                } label: {
                    Label("Have an offer code?", systemImage: "ticket")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? wspProduct.themeColor : Color.clear, lineWidth: 2)
        )
    }
}
