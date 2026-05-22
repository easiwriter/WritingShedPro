import SwiftUI
import StoreKit

/// Paywall view for the Manuscript Analyst subscription service.
struct ManuscriptAnalystPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var showTrialTerms = false
    @State private var purchaseError: String?
    var onSubscribe: (() -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Hero section
                VStack(spacing: 12) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.cyan)
                    
                    VStack(spacing: 8) {
                        Text("Manuscript Analyst")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("AI-Powered Editorial Feedback")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 12)

                Divider()

                // Features list
                VStack(alignment: .leading, spacing: 8) {
                    featureRow("text.magnifyingglass", "Smart editorial suggestions tailored to your genre", .cyan)
                    featureRow("chart.line", "Track writing improvements over time", .green)
                    featureRow("lightning.bolt", "Analyze entire manuscripts in seconds", .orange)
                    featureRow("brain.fill", "AI powered by Claude 3.5 Sonnet", .purple)
                }
                .padding(.vertical, 8)

                Divider()

                // Pricing info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Subscription Plans")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("$5.99/month")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.cyan)
                        }
                        Spacer()
                        VStack(alignment: .leading, spacing: 4) {
                            Text("First Month")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                            Text("FREE")
                                .font(.headline)
                                .foregroundStyle(.green)
                        }
                    }
                    .padding(12)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
                .padding(.vertical, 4)

                Spacer(minLength: 0)

                // CTA buttons
                VStack(spacing: 12) {
                    Button(action: { Task { await purchaseSubscription() } }) {
                        Group {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Start Free Trial", systemImage: "star.fill")
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.cyan)
                        .cornerRadius(8)
                    }
                    .disabled(isPurchasing)

                    Button(action: { dismiss() }) {
                        Text("Maybe Later")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .foregroundStyle(.cyan)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Fine print
                Button(action: { showTrialTerms = true }) {
                    Label("Trial Terms", systemImage: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .alert("Trial Terms", isPresented: $showTrialTerms) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("First month free, then $5.99/month. Cancel anytime in App Store subscription settings. Billed to your Apple ID account.")
            }
            .alert("Purchase Error", isPresented: Binding(
                get: { purchaseError != nil },
                set: { if !$0 { purchaseError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(purchaseError ?? "")
            }
        }
    }

    private func purchaseSubscription() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let productID = WSPProduct.manuscriptAnalystSubscription.rawValue
            let products = try await Product.products(for: [productID])
            guard let product = products.first else {
                purchaseError = "Subscription not available. Please try again later."
                return
            }
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    EntitlementManager.shared.recordVerifiedPurchase(transaction.productID)
                    await EntitlementManager.shared.refreshEntitlements()
                    onSubscribe?()
                    dismiss()
                }
            case .userCancelled:
                break
            case .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    private func featureRow(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}
