//
//  UpgradePromptView.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import SwiftUI
import StoreKit
import StoreKitManager

/// A reusable view for showing upgrade prompts when users hit free tier limits.
/// Displays context-specific messaging and provides path to purchase.
@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
struct UpgradePromptView: View {
    let reason: UpgradePromptReason
    @Binding var isPresented: Bool
    var onPurchaseCompleted: (() -> Void)?
    
    /// State for showing the store
    @State private var showStore = false

    private var isNewPurchaseModel: Bool {
        EntitlementManager.shared.purchaseModel == .trialAndFullAccess
    }

    private var targetProduct: WSPProduct {
        .fullAccess
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundStyle(iconGradient)
            
            // Title
            Text(NSLocalizedString("iap.readOnly.title", comment: "Full Access required"))
                .font(.title2)
                .fontWeight(.semibold)
            
            // Message
            Text(isNewPurchaseModel ? NSLocalizedString("iap.readOnly.message", comment: "Trial expired read-only message") : NSLocalizedString("iap.fullAccess.legacyMessage", comment: "Legacy feature requires Full Access"))
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Benefit highlight
            VStack(alignment: .leading, spacing: 8) {
                benefitRow(icon: "infinity", text: "Unlimited projects")
                benefitRow(icon: "doc.on.doc", text: "Unlimited files")
                benefitRow(icon: "square.and.arrow.up", text: "Export to PDF, Word, RTF, EPUB")
                benefitRow(icon: "printer", text: "Full printing support")
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                Button {
                    showStore = true
                } label: {
                    Text(
                        NSLocalizedString("iap.fullAccess.unlock", comment: "Unlock Full Access")
                    )
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(productColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button("Not Now") {
                    isPresented = false
                }
                .foregroundColor(.secondary)
            }
            .padding(.bottom)
        }
        .padding()
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showStore) {
            StoreView(
                highlightedProduct: targetProduct,
                autoPurchaseProduct: targetProduct
            )
        }
        .onChange(of: showStore) { _, isShowing in
            // When store closes, refresh entitlements and check if purchase succeeded
            if !isShowing {
                Task {
                    await EntitlementManager.shared.refreshEntitlements()
                    await MainActor.run {
                        if EntitlementManager.shared.isProjectTypeUnlocked(reason.projectType) {
                            // User purchased! Dismiss the upgrade prompt and notify caller
                            isPresented = false
                            onPurchaseCompleted?()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(productColor)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
        }
    }
    
    // MARK: - Styling
    
    private var iconName: String {
        if isNewPurchaseModel {
            return "lock.fill"
        }
        switch reason {
        case .projectLimit:
            return "folder.badge.plus"
        case .fileLimit:
            return "doc.badge.plus"
        case .exportBlocked:
            return "square.and.arrow.up.trianglebadge.exclamationmark"
        case .printBlocked:
            return "printer.dotmatrix"
        }
    }
    
    private var iconGradient: LinearGradient {
        LinearGradient(
            colors: [productColor, productColor.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var productColor: Color {
        if isNewPurchaseModel {
            return .green
        }
        switch reason.projectType {
        case .prose:
            return .blue
        case .poetry:
            return .purple
        case .fiction:
            return .orange
        case .drama:
            return .red
        }
    }

}

// MARK: - Alert Modifier for Upgrade Prompts

@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
extension View {
    /// Shows an upgrade prompt alert when a free tier limit is hit
    func upgradePrompt(reason: Binding<UpgradePromptReason?>, onPurchaseCompleted: (() -> Void)? = nil) -> some View {
        self.sheet(item: reason) { promptReason in
            UpgradePromptView(
                reason: promptReason,
                isPresented: Binding(
                    get: { reason.wrappedValue != nil },
                    set: { if !$0 { reason.wrappedValue = nil } }
                ),
                onPurchaseCompleted: onPurchaseCompleted
            )
        }
    }
}

// MARK: - Identifiable Conformance

@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
extension UpgradePromptReason: Identifiable {
    var id: String {
        switch self {
        case .projectLimit(let type):
            return "projectLimit-\(type.rawValue)"
        case .fileLimit(let type):
            return "fileLimit-\(type.rawValue)"
        case .exportBlocked(let type):
            return "exportBlocked-\(type.rawValue)"
        case .printBlocked(let type):
            return "printBlocked-\(type.rawValue)"
        }
    }
}
