//
//  StoreView.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import SwiftUI
import StoreKit
import StoreKitManager

/// Purchase option tabs
enum PurchaseTab: String, CaseIterable {
    case bundle = "Bundle Deal"
    case individual = "Individual"
}

/// Main store view for purchasing Writing Shed Pro modules
@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
struct StoreView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var storeManager = StoreKitPurchaseManager.shared
    
    /// Optional: highlight a specific product (from upgrade prompt)
    var highlightedProduct: WSPProduct?

    /// Optional: automatically trigger the StoreKit payment sheet for this product once loaded
    var autoPurchaseProduct: WSPProduct? = nil
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showRestoreSuccess = false
    @State private var purchaseInProgress: String?
    @State private var loadedProducts: [Product] = []
    @State private var selectedTab: PurchaseTab = .bundle
    
    /// Available tabs - excludes bundle if user has purchased any individual module
    private var availableTabs: [PurchaseTab] {
        if EntitlementManager.shared.hasAnyIndividualModulePurchase {
            return [.individual]  // Only show individual tab
        }
        return PurchaseTab.allCases
    }
    
    /// Whether to show the tab picker (only if more than one tab available)
    private var showTabPicker: Bool {
        availableTabs.count > 1
    }
    
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
                    } else {
                        // Tab picker to switch between views (hidden if only one tab available)
                        if showTabPicker {
                            purchaseTabPicker
                        }
                        
                        // Content based on selected tab
                        switch selectedTab {
                        case .bundle:
                            bundleTabContent
                        case .individual:
                            individualTabContent
                        }
                        
                        // Restore purchases
                        restoreSection
                        
                        // Terms and privacy
                        legalSection
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Writing Modules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not Now") {
                        dismiss()
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
                        EntitlementManager.shared.recordVerifiedPurchase(transaction.productID)
                        await EntitlementManager.shared.refreshEntitlements()
                    }
                }
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your purchases have been restored successfully.")
            }
            .onAppear {
                // Route initial tab based on the highlighted product from upgrade prompts.
                if let highlightedProduct {
                    selectedTab = highlightedProduct == .allInBundle ? .bundle : .individual
                }

                // If user has purchased any individual module, default to individual tab
                // (bundle is no longer a good deal for them).
                if EntitlementManager.shared.hasAnyIndividualModulePurchase {
                    selectedTab = .individual
                }
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
            
            Text("Unlock Your Writing Potential")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Choose a bundle or purchase modules individually")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 8)
    }
    
    private var purchaseTabPicker: some View {
        Picker("Purchase Option", selection: $selectedTab) {
            ForEach(PurchaseTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 4)
    }
    
    private var bundleTabContent: some View {
        VStack(spacing: 16) {
            // Bundle card
            if let bundleProduct = product(for: .allInBundle) {
                BundleCardView(
                    product: bundleProduct,
                    isPurchased: EntitlementManager.shared.hasBundle,
                    isLoading: purchaseInProgress == bundleProduct.id,
                    savingsPercentage: bundleSavingsPercentage,
                    onPurchase: { await purchase(bundleProduct) },
                    onRedeemCode: { presentOfferCodeRedemption() }
                )
            }
            

            analystSubscriptionSection
            // Hint to see individual options
            if !EntitlementManager.shared.hasBundle {
                Button {
                    withAnimation {
                        selectedTab = .individual
                    }
                } label: {
                    HStack {
                        Text("Or buy just what you need")
                            .font(.subheadline)
                        Image(systemName: "arrow.right.circle")
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var individualTabContent: some View {
        VStack(spacing: 16) {
            // Quick link back to bundle (hidden if user already has bundle or any individual purchase)
            if !EntitlementManager.shared.hasBundle && !EntitlementManager.shared.hasAnyIndividualModulePurchase {
                Button {
                    withAnimation {
                        selectedTab = .bundle
                    }
                } label: {
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.purple)
                        Text(bundleSavingsCalloutText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Image(systemName: "arrow.right.circle")
                    }
                    .foregroundColor(.purple)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.purple.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            
            // Individual modules
            ForEach(WSPProduct.individualModules, id: \.rawValue) { wspProduct in
                if let storeProduct = product(for: wspProduct) {
                    ModuleCardView(
                        wspProduct: wspProduct,
                        storeProduct: storeProduct,
                        isPurchased: EntitlementManager.shared.isModulePurchased(wspProduct),
                        isHighlighted: highlightedProduct == wspProduct,
                        isLoading: purchaseInProgress == storeProduct.id,
                        onPurchase: { await purchase(storeProduct) },
                        onRedeemCode: { presentOfferCodeRedemption() }
                    )
                }
            }

            analystSubscriptionSection
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
        #if !targetEnvironment(macCatalyst)
        // On iOS, use the offer code redemption sheet
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        Task {
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
                
                // Refresh entitlements after redemption
                try? await Task.sleep(for: .seconds(2))
                await EntitlementManager.shared.refreshEntitlements()
            } catch {
                print("Failed to present offer code sheet: \(error)")
            }
        }
        #else
        // On Mac Catalyst, direct users to the App Store
        if let url = URL(string: "https://apps.apple.com/redeem") {
            UIApplication.shared.open(url)
        }
        #endif
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

    private var bundleSavingsPercentage: Int? {
        WSPBundleSavings.percentage(products: loadedProducts)
    }

    private var bundleSavingsCalloutText: String {
        if let bundleSavingsPercentage {
            return "Save \(bundleSavingsPercentage)% with the All-In Bundle"
        }
        return "Save with the All-In Bundle"
    }
    
    private func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load products with our product IDs
            let allIDs = WSPProduct.allCases.map { $0.rawValue }
            let products = try await Product.products(for: allIDs)
            
            await MainActor.run {
                loadedProducts = products
                isLoading = false
                
                if products.isEmpty {
                    errorMessage = "No products available. Please try again later."
                }
                
                #if DEBUG
                print("📦 Loaded \(products.count) products: \(products.map { $0.id })")
                #endif
            }

            // Auto-trigger the payment sheet if requested (e.g. bundle CTA in upgrade prompt)
            if let target = autoPurchaseProduct,
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
        purchaseInProgress = product.id
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    // Record immediately so the entitlement is available even if
                    // Transaction.currentEntitlements hasn't updated yet (iOS timing issue).
                    EntitlementManager.shared.recordVerifiedPurchase(transaction.productID)
                    await EntitlementManager.shared.refreshEntitlements()
                    // Dismiss the store after successful purchase
                    await MainActor.run {
                        dismiss()
                    }
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            #if DEBUG
            print("❌ Purchase failed: \(error.localizedDescription)")
            #endif
        }
        
        purchaseInProgress = nil
    }
    
    private func restorePurchases() async {
        do {
            try await AppStore.sync()
            await EntitlementManager.shared.refreshEntitlements()
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
                    Label("Owned", systemImage: "checkmark.circle.fill")
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

// MARK: - Bundle Card View

@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
struct BundleCardView: View {
    let product: Product
    let isPurchased: Bool
    let isLoading: Bool
    let savingsPercentage: Int?
    let onPurchase: () async -> Void
    let onRedeemCode: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Best Value badge
            if !isPurchased {
                Text(savingsPercentage.map { "BEST VALUE - SAVE \($0)%" } ?? "BEST VALUE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .clipShape(Capsule())
            }
            
            // Title
            HStack {
                Image(systemName: "gift.fill")
                    .font(.title)
                    .foregroundColor(.purple)
                Text("All-In Bundle")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Description
            Text("Unlock all four writing modules with one purchase")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Included modules
            HStack(spacing: 20) {
                ForEach(WSPProduct.individualModules, id: \.rawValue) { module in
                    VStack(spacing: 4) {
                        Image(systemName: module.iconName)
                            .font(.title3)
                            .foregroundColor(module.themeColor)
                        Text(module.displayName.components(separatedBy: " ").first ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            
            // Price / Status
            if isPurchased {
                Label("All Modules Owned", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundColor(.green)
            } else if isLoading {
                ProgressView()
                    .padding()
            } else {
                Button {
                    Task { await onPurchase() }
                } label: {
                    Text("Get All for \(product.displayPrice)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Offer code link
                Button {
                    onRedeemCode()
                } label: {
                    Label("Have an offer code?", systemImage: "ticket")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.purple.opacity(0.5), .blue.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
    }
}
