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
    
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showRestoreSuccess = false
    @State private var purchaseInProgress: String?
    @State private var loadedProducts: [Product] = []
    @State private var selectedTab: PurchaseTab = .bundle
    
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
                        // Tab picker to switch between views
                        purchaseTabPicker
                        
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
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadProducts()
            }
            .alert("Purchases Restored", isPresented: $showRestoreSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your purchases have been restored successfully.")
            }
            .onAppear {
                // If a specific product is highlighted, switch to individual tab
                if highlightedProduct != nil {
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
                    onPurchase: { await purchase(bundleProduct) }
                )
            }
            
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
            // Quick link back to bundle
            if !EntitlementManager.shared.hasBundle {
                Button {
                    withAnimation {
                        selectedTab = .bundle
                    }
                } label: {
                    HStack {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.purple)
                        Text("Save 25% with the All-In Bundle")
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
                        onPurchase: { await purchase(storeProduct) }
                    )
                }
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
        }
        .padding(.top, 20)
    }
    
    private var legalSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://writingshedpro.com/terms")!)
                Text("•")
                    .foregroundColor(.secondary)
                Link("Privacy Policy", destination: URL(string: "https://writingshedpro.com/privacy")!)
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
                    await EntitlementManager.shared.refreshEntitlements()
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
    
    var body: some View {
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
    let onPurchase: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // Best Value badge
            if !isPurchased {
                Text("BEST VALUE – SAVE 25%")
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
