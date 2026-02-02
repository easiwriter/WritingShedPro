//
//  UpgradePromptView.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import SwiftUI
import StoreKitManager

/// A reusable view for showing upgrade prompts when users hit free tier limits.
/// Displays context-specific messaging and provides path to purchase.
@available(macCatalyst 15, macOS 14.4, iOS 17.4, *)
struct UpgradePromptView: View {
    let reason: UpgradePromptReason
    @Binding var isPresented: Bool
    
    /// State for showing the store
    @State private var showStore = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 32))
                .foregroundStyle(iconGradient)
            
            // Title
            Text(reason.title)
                .font(.title2)
                .fontWeight(.semibold)
            
            // Message
            Text(reason.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            // Benefit highlight
            VStack(alignment: .leading, spacing: 8) {
                benefitRow(icon: "infinity", text: "Unlimited projects")
                benefitRow(icon: "doc.on.doc", text: "Unlimited files")
                benefitRow(icon: "square.and.arrow.up", text: "Export to PDF, Word, RTF")
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
                    Text("View \(reason.requiredProduct.displayName)")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(productColor)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Also show bundle option if not already requesting it
                if reason.requiredProduct != .allInBundle {
                    Button {
                        showStore = true
                    } label: {
                        HStack {
                            Text("Or get the")
                            Text("All-In Bundle")
                                .fontWeight(.semibold)
                            Text("- Save 30%")
                                .foregroundColor(.green)
                        }
                        .font(.subheadline)
                    }
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
            StoreView(highlightedProduct: reason.requiredProduct)
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
    func upgradePrompt(reason: Binding<UpgradePromptReason?>) -> some View {
        self.sheet(item: reason) { promptReason in
            UpgradePromptView(
                reason: promptReason,
                isPresented: Binding(
                    get: { reason.wrappedValue != nil },
                    set: { if !$0 { reason.wrappedValue = nil } }
                )
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
